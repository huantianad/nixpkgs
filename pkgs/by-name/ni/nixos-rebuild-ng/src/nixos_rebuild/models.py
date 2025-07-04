import platform
import re
import subprocess
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any, ClassVar, Self, TypedDict, override

from .process import Remote, run_wrapper

type ImageVariants = list[str]


class NixOSRebuildError(Exception):
    "nixos-rebuild general error."

    def __init__(self, message: str) -> None:
        self.message = message

    @override
    def __str__(self) -> str:
        return f"error: {self.message}"


class Action(Enum):
    SWITCH = "switch"
    BOOT = "boot"
    TEST = "test"
    BUILD = "build"
    EDIT = "edit"
    REPL = "repl"
    DRY_BUILD = "dry-build"
    DRY_RUN = "dry-run"
    DRY_ACTIVATE = "dry-activate"
    BUILD_IMAGE = "build-image"
    BUILD_VM = "build-vm"
    BUILD_VM_WITH_BOOTLOADER = "build-vm-with-bootloader"
    LIST_GENERATIONS = "list-generations"

    @override
    def __str__(self) -> str:
        return self.value

    @staticmethod
    def values() -> list[str]:
        return [a.value for a in Action]


@dataclass(frozen=True)
class BuildAttr:
    path: str | Path
    attr: str | None

    def to_attr(self, *attrs: str) -> str:
        return f"{self.attr + '.' if self.attr else ''}{'.'.join(attrs)}"

    @classmethod
    def from_arg(cls, attr: str | None, file: str | None) -> Self:
        if not (attr or file):
            return cls("<nixpkgs/nixos>", None)
        return cls(Path(file or "default.nix"), attr)


def discover_git(location: Path) -> Path | None:
    """
    Discover the current git repository in the given location.
    """
    current = location.resolve()
    previous = None

    while current.is_dir() and current != previous:
        dotgit = current / ".git"
        if dotgit.is_dir():
            return current
        elif dotgit.is_file():  # this is a worktree
            with dotgit.open() as f:
                dotgit_content = f.read().strip()
                if dotgit_content.startswith("gitdir: "):
                    return Path(dotgit_content.split("gitdir: ")[1])
        previous = current
        current = current.parent

    return None


def discover_closest_flake(location: Path) -> Path | None:
    """
    Discover the closest flake.nix file starting from the given location upwards.
    """
    current = location.resolve()
    previous = None

    while current.is_dir() and current != previous:
        flake_file = current / "flake.nix"
        if flake_file.is_file():
            return current
        previous = current
        current = current.parent

    return None


def get_hostname(target_host: Remote | None) -> str | None:
    if target_host:
        try:
            return run_wrapper(
                ["uname", "-n"],
                capture_output=True,
                remote=target_host,
            ).stdout.strip()
        except (AttributeError, subprocess.CalledProcessError):
            return None
    else:
        return platform.node()


@dataclass(frozen=True)
class Flake:
    path: Path | str
    attr: str
    _re: ClassVar = re.compile(r"^(?P<path>[^\#]*)\#?(?P<attr>[^\#\"]*)$")

    def to_attr(self, *attrs: str) -> str:
        return f"{self}.{'.'.join(attrs)}"

    @override
    def __str__(self) -> str:
        return f"{self.path}#{self.attr}"

    @classmethod
    def parse(cls, flake_str: str, target_host: Remote | None = None) -> Self:
        m = cls._re.match(flake_str)
        assert m is not None, f"got no matches for {flake_str}"
        attr = m.group("attr")
        nixos_attr = (
            f'nixosConfigurations."{attr or get_hostname(target_host) or "default"}"'
        )
        path_str = m.group("path")
        if ":" in path_str:
            return cls(path_str, nixos_attr)
        else:
            path = Path(path_str)
            git_repo = discover_git(path)
            if git_repo is not None:
                url = f"git+file://{git_repo}"
                flake_path = discover_closest_flake(path)
                if (
                    flake_path is not None
                    and flake_path != git_repo
                    and flake_path.is_relative_to(git_repo)
                ):
                    url += f"?dir={flake_path.relative_to(git_repo)}"
                return cls(url, nixos_attr)
            return cls(path, nixos_attr)

    @classmethod
    def from_arg(cls, flake_arg: Any, target_host: Remote | None) -> Self | None:  # noqa: ANN401
        match flake_arg:
            case str(s):
                return cls.parse(s, target_host)
            case True:
                return cls.parse(".", target_host)
            case False:
                return None
            case _:
                # Use /etc/nixos/flake.nix if it exists.
                default_path = Path("/etc/nixos/flake.nix")
                if default_path.exists():
                    # It can be a symlink to the actual flake.
                    default_path = default_path.resolve()
                    return cls.parse(str(default_path.parent), target_host)
                else:
                    return None


@dataclass(frozen=True)
class Generation:
    id: int
    timestamp: str  # we may want to have a proper timestamp type in future
    current: bool


# camelCase since this will be used as output for `--json` flag
class GenerationJson(TypedDict):
    generation: int
    date: str
    nixosVersion: str
    kernelVersion: str
    configurationRevision: str
    specialisations: list[str]
    current: bool


@dataclass(frozen=True)
class Profile:
    name: str
    path: Path

    @classmethod
    def from_arg(cls, name: str) -> Self:
        match name:
            case "system":
                return cls(name, Path("/nix/var/nix/profiles/system"))
            case _:
                path = Path("/nix/var/nix/profiles/system-profiles") / name
                path.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
                return cls(name, path)

{
  lib,
  buildPythonPackage,
  fetchPypi,
  pythonOlder,

  # build-system
  setuptools,

  # dependencies
  boto3,
  botocore,
  cryptography,
  jinja2,
  python-dateutil,
  requests,
  responses,
  werkzeug,
  xmltodict,

  # optional-dependencies
  antlr4-python3-runtime,
  aws-xray-sdk,
  cfn-lint,
  flask,
  flask-cors,
  docker,
  graphql-core,
  joserfc,
  jsonpath-ng,
  jsondiff,
  multipart,
  openapi-spec-validator,
  py-partiql-parser,
  pyparsing,
  pyyaml,

  # tests
  freezegun,
  pytestCheckHook,
  pytest-order,
  pytest-xdist,
}:

buildPythonPackage rec {
  pname = "moto";
  version = "5.0.15";
  pyproject = true;

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-V6qMKvQXzGSg3f5j5bzRrakPUHm3PN0fdMTp+zChp+Y=";
  };

  build-system = [ setuptools ];

  dependencies = [
    boto3
    botocore
    cryptography
    requests
    xmltodict
    werkzeug
    python-dateutil
    responses
    jinja2
  ];

  optional-dependencies = {
    # non-exhaustive list of extras, that was cobbled together for testing
    all = [
      antlr4-python3-runtime
      aws-xray-sdk
      cfn-lint
      docker
      flask
      flask-cors
      graphql-core
      joserfc
      jsondiff
      jsonpath-ng
      multipart
      openapi-spec-validator
      pyparsing
      py-partiql-parser
      pyyaml
      setuptools
    ];
    cognitoidp = [ joserfc ];
  };

  __darwinAllowLocalNetworking = true;

  nativeCheckInputs = [
    freezegun
    pytestCheckHook
    pytest-order
    pytest-xdist
  ] ++ optional-dependencies.all;

  # Some tests depend on AWS credentials environment variables to be set.
  env.AWS_ACCESS_KEY_ID = "ak";
  env.AWS_SECRET_ACCESS_KEY = "sk";

  pytestFlagsArray = [
    "-m"
    "'not network and not requires_docker'"

    # Matches upstream configuration, presumably due to expensive setup/teardown.
    "--dist"
    "loadscope"

    # Fails at local name resolution
    "--deselect=tests/test_s3/test_multiple_accounts_server.py::TestAccountIdResolution::test_with_custom_request_header"
    "--deselect=tests/test_s3/test_server.py::test_s3_server_post_cors_multiple_origins"
    "--deselect=tests/test_s3/test_s3_file_handles.py::TestS3FileHandleClosuresUsingMocks::test_create_multipart"
    "--deselect=tests/test_core/test_responses_module.py::TestResponsesMockWithPassThru::test_aws_and_http_requests"
    "--deselect=tests/test_core/test_responses_module.py::TestResponsesMockWithPassThru::test_http_requests"

    # Fails at resolving google.com
    "--deselect=tests/test_firehose/test_firehose_put.py::test_put_record_http_destination"
    "--deselect=tests/test_firehose/test_firehose_put.py::test_put_record_batch_http_destination"

    # Fails at resolving s3.amazonaws.com
    "--deselect=tests/test_core/test_request_passthrough.py::test_passthrough_calls_for_wildcard_urls"
    "--deselect=tests/test_core/test_request_passthrough.py::test_passthrough_calls_for_specific_url"
    "--deselect=tests/test_core/test_request_passthrough.py::test_passthrough_calls_for_entire_service"

    # Download recordings returns faulty JSON
    "--deselect=tests/test_moto_api/recorder/test_recorder.py::TestRecorder::test_ec2_instance_creation_recording_on"
    "--deselect=tests/test_moto_api/recorder/test_recorder.py::TestRecorder::test_ec2_instance_creation__recording_off"

    # Connection Reset by Peer, when connecting to localhost:5678
    "--deselect=tests/test_moto_api/recorder/test_recorder.py::TestRecorder::test_replay"

    # Flaky under parallel execution
    "--deselect=tests/test_cloudformation/test_server.py::test_cloudformation_server_get"
    "--deselect=tests/test_core/test_moto_api.py::TestModelDataResetForClassDecorator::test_should_find_bucket"

    # AssertionError: assert ResourceWarning not in [<class 'ResourceWarning'>, <class 'ResourceWarning'>]
    "--deselect=ests/test_s3/test_s3_file_handles.py::TestS3FileHandleClosuresUsingMocks::test_delete_object_with_version"
  ];

  disabledTestPaths = [
    # Flaky under parallel execution, Connection Reset errors to localhost.
    "tests/test_moto_api/recorder/test_recorder.py"

    # Flaky under parallel execution
    "tests/test_resourcegroupstaggingapi/*.py"

    # Tries to access the network
    "tests/test_batch/test_batch_jobs.py"

    # Threading tests regularly blocks test execution
    "tests/test_utilities/test_threaded_server.py"
    "tests/test_s3/test_s3_bucket_policy.py"

    # https://github.com/getmoto/moto/issues/7786
    "tests/test_dynamodb/test_dynamodb_import_table.py"

    # Infinite recursion with pycognito
    "tests/test_cognitoidp/test_cognitoidp.py"
  ];

  meta = with lib; {
    description = "Allows your tests to easily mock out AWS Services";
    homepage = "https://github.com/getmoto/moto";
    changelog = "https://github.com/getmoto/moto/blob/${version}/CHANGELOG.md";
    license = licenses.asl20;
    maintainers = [ ];
  };
}

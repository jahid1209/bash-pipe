# Bitbucket Pipelines Pipe: bash-pipe

A  pipe to run SCA and SAST security scans

## Docker image size
The base image is `ubuntu:latest` and the size is [311.98 MB](https://hub.docker.com/layers/j1209/bash-pipe/1.0.0/images/sha256-ec015454bb6193ea5119830f0927913a334b70e3bcf4d5b6c9975fc1265f95db?context=explore)


## YAML Definition

Add the following snippet to the script section of your `bitbucket-pipelines.yml` file:

```yaml
script:
  - pipe: docker://j1209/bash-pipe:1.0.0
    variables:
      BRIDGE_BLACKDUCK_URL: "<string>"
      BRIDGE_BLACKDUCK_TOKEN: "<string>"
      # DEBUG: "<boolean>" # Optional
```
## Variables

| Variable | Usage                                              |
|----------|----------------------------------------------------|
| BRIDGE_BLACKDUCK_URL (*) | The Blackduck Hub URL          |
| BRIDGE_BLACKDUCK_URL  (*)  | The token to establish connection with the Blackduck Hub |

_(*) = required variable for Blacduck Scan._


## Support
If you’d like help with this pipe, or you have an issue or feature request, let us know.
The pipe is maintained by jahid1209.

If you’re reporting an issue, please include:

- the version of the pipe
- relevant logs and error messages
- steps to reproduce

## License
Copyright (c) 2019 Atlassian and others.
Apache 2.0 licensed, see [LICENSE](LICENSE.txt) file.

# github-action-tflint-upload [![Latest Release](https://img.shields.io/github/release/The-Infra-Company/github-action-tflint-upload.svg)](https://github.com/The-Infra-Company/github-action-tflint-upload/releases/latest)

A GitHub Action to run tflint and post the results to the GitHub Security tab.

![findings](./docs/tflint-findings.png)

## Usage

```yaml
name: TFLint

on:
  pull_request:
    branches: [ 'main' ]
    types: [ opened, synchronize, reopened, closed, labeled, unlabeled ]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - name: Clone repo
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init
        working-directory: "terraform/modules/vpc"

      - name: Run TFLint
        uses: The-Infra-Company/github-action-tflint-upload@a742d2ea7d35dc6a3cc8e929daf199f5e9a848ae # v0.2.0
        env:
          DEBUG_MODE: "true"
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          tflint_version: "v0.49.0" # TFLint added a "Bug Fix" with v0.50.0 that added .tflint.hcl as a requirement
          working_directory: "terraform/modules/vpc"
          tflint_rulesets: "aws"
          flags: >-
            --disable-rule=terraform_unused_required_providers
            --disable-rule=terraform_deprecated_index
```

<!-- action-docs-inputs source="action.yml" -->
## Inputs

| name | description | required | default |
| --- | --- | --- | --- |
| `github_token` | <p>GITHUB_TOKEN</p> | `true` | `${{ github.token }}` |
| `working_directory` | <p>Directory to run the action on, from the repo root. Default is . (root of the repository)</p> | `false` | `.` |
| `tflint_version` | <p>The tflint version to install and use. Default is to use the latest release version.</p> | `false` | `latest` |
| `tflint_rulesets` | <p>Space separated, official (from the terraform-linters GitHub organization) tflint rulesets to install and use. If a pre-configured <code>TFLINT_PLUGIN_DIR</code> is set, rulesets are installed in that directory. Default is empty.</p> | `false` | `""` |
| `tflint_init` | <p>Whether or not to run tflint --init prior to running scan [true,false] Default is <code>false</code>.</p> | `false` | `false` |
| `tflint_target_dir` | <p>The target dir for the tflint command. This is the directory passed to tflint as opposed to working_directory which is the directory the command is executed from. Default is . (root of the repository)</p> | `false` | `.` |
| `tflint_config` | <p>Config file name for tflint. Default is <code>.tflint.hcl</code>.</p> | `false` | `.tflint.hcl` |
| `flags` | <p>List of arguments to send to tflint For the output to be parsable by reviewdog --format=checkstyle is enforced Default is --call-module-type=all.</p> | `false` | `--call-module-type=all` |
<!-- action-docs-inputs source="action.yml" -->

<!-- action-docs-outputs source="action.yml" -->
## Outputs

| name | description |
| --- | --- |
| `tflint-return-code` | <p>tflint command return code</p> |
<!-- action-docs-outputs source="action.yml" -->

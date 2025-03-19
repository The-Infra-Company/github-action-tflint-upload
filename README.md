# github-action-tflint-upload [![Latest Release](https://img.shields.io/github/release/The-Infra-Company/github-action-tflint-upload.svg)](https://github.com/cloudposse/github-action-tflint-upload/releases/latest)

A GitHub Action to run tflint and post the results to the GitHub Security tab.

## Usage

```yaml
  name: Pull Request
  on:
    pull_request:
      branches: [ 'main' ]
      types: [opened, synchronize, reopened, closed, labeled, unlabeled]

  jobs:
    context:
      runs-on: ubuntu-latest
      steps:
        - name: tflint
          uses: The-Infra-Company/github-action-tflint-upload@main
          with:
            github_token: ${{ secrets.GITHUB_TOKEN }}
            working_directory: "infra" # Optional. Change working directory
            tflint_rulesets: "azurerm google" # Optional. Extra official rulesets to install
            flags: "--call-module-type=all" # Optional. Add custom tflint flags
```

<!-- action-docs-inputs source="action.yml" -->
## Inputs

| name | description | required | default |
| --- | --- | --- | --- |
| `github_token` | <p>GITHUB_TOKEN</p> | `true` | `${{ github.token }}` |
| `working_directory` | <p>Directory to run the action on, from the repo root. Default is . ( root of the repository)</p> | `false` | `.` |
| `tflint_version` | <p>The tflint version to install and use. Default is to use the latest release version.</p> | `false` | `v0.49.0` |
| `tflint_rulesets` | <p>Space separated, official (from the terraform-linters GitHub organization) tflint rulesets to install and use. If a pre-configured <code>TFLINT_PLUGIN_DIR</code> is set, rulesets are installed in that directory. Default is empty.</p> | `false` | `""` |
| `tflint_init` | <p>Whether or not to run tflint --init prior to running scan [true,false] Default is <code>false</code>.</p> | `false` | `false` |
| `tflint_target_dir` | <p>The target dir for the tflint command. This is the directory passed to tflint as opposed to working_directory which is the directory the command is executed from. Default is . ( root of the repository)</p> | `false` | `.` |
| `tflint_config` | <p>Config file name for tflint. Default is <code>.tflint.hcl</code>.</p> | `false` | `.tflint.hcl` |
| `flags` | <p>List of arguments to send to tflint Default is --call-module-type=all.</p> | `false` | `--call-module-type=all` |
<!-- action-docs-inputs source="action.yml" -->

<!-- action-docs-outputs source="action.yml" -->
## Outputs

| name | description |
| --- | --- |
| `tflint-return-code` | <p>tflint command return code</p> |
<!-- action-docs-outputs source="action.yml" -->

# Github Workflows

Reusable workflows and actions

## Fork Features and Changes

This fork (`llmzy/github-workflows`) adds several key features and modifications to the original [salesforcecli/github-workflows](https://github.com/salesforcecli/github-workflows) project:

### Package Manager Support

- Added support for both npm and yarn package managers
- New `package-manager` input parameter (default: "yarn") to specify which package manager to use
- Automatic detection and use of the appropriate package manager commands

### Git Commit Signing

- Added support for signed Git commits in workflows
- Automatic configuration of Git signing with GPG keys
- Email verification to ensure GPG key matches GitHub token identity
- Secure handling of private keys through GitHub Secrets

#### Setting Up Git Commit Signing

1. Generate a GPG key:

   ```bash
   gpg --full-generate-key
   ```

   - Choose RSA and RSA (default)
   - Choose 4096 bits
   - Choose how long the key should be valid
     - Setting an expiration date is a security best practice
     - You can extend the key's validity before it expires using `gpg --edit-key YOUR_EMAIL`
     - If the key expires, you'll need to generate a new one and update the GitHub secrets
   - Enter your name and email (should match your GitHub account email)
   - Do not supply a passphrase as it would be necessary to store both in
     GitHub secrets. We will delete the local copy in step 5.

2. Export your private key:

   ```bash
   # First, list your keys to get the key ID
   gpg --list-secret-keys --keyid-format=long YOUR_EMAIL
   
   # Then export the specific key using its ID
   gpg --export-secret-keys --armor KEY_ID > private.asc
   ```

   - Replace `YOUR_EMAIL` with the email you used when creating the key
   - Replace `KEY_ID` with the key ID from the list command (it will look like `ABCD1234EFGH5678`)
   - The output will be in ASCII-armored format

3. Export your public key and add it to GitHub:

   ```bash
   # Export the public key using the same key ID
   gpg --export --armor KEY_ID > public.asc
   ```

   - Use the same `KEY_ID` from step 2
   - Copy the contents of public.asc
     - On macOS, you can use: `cat public.asc | pbcopy`
     - Otherwise, open the file and copy its contents
   - Go to GitHub Settings > SSH and GPG keys > New GPG key
   - Paste the public key content
   - Give it a descriptive title (e.g., "CI Workflow Signing Key")
   - Click "Add GPG key"

4. Add the secrets to your GitHub repository or organization:
   - Go to your repository's Settings > Secrets and variables > Actions
   - Add the following secrets:
     - `LLMZY_CI_PRIVATE_KEY`: The contents of your private.asc file
       - On macOS, you can use: `cat private.asc | pbcopy`
       - Otherwise, open the file and copy its contents
     - `SVC_CLI_BOT_GITHUB_TOKEN`: A GitHub PAT with repo access (if not already set)

5. Clean up sensitive files and clipboard:

   ```bash
   rm private.asc public.asc
   echo | pbcopy
   ```

   - This removes the local copies of your keys
   - The private key is now only stored securely in GitHub Secrets

6. The workflows will automatically:
   - Configure Git with your signing key
   - Verify that the GPG key email matches your GitHub token identity
   - Sign all commits made by the workflows
   - Clean up the signing configuration after the workflow completes

### GitHub Packages Publishing

- Added support for publishing to GitHub Packages Registry
- New `publishToGithubPackages` input parameter (default: false)
- New `scope` input parameter for package scoping (required when publishing to GitHub Packages)
- Automatic configuration of npm/yarn for GitHub Packages authentication
- Proper handling of GitHub Packages permissions and authentication tokens

### Changelog Management

- Added date-based changelog filtering with the new `first-release-date` parameter
- Automatic counting of releases since a specified date for cleaner changelogs
- Smart fallback to full history if no releases exist since the cutoff date
- Compatible with both current and legacy GitHub release workflows

### Prerelease Handling

- Enhanced prerelease handling with better validation
- New validation to prevent prerelease creation on main branch
- Improved prerelease tag management

### Repository References

- Updated action references to use the fork's repository
- Maintained compatibility with original workflow structure while adding new features

## Documentation

> [!IMPORTANT]
> Many of these workflows require a Personal Access Token to function.
>
> - Create a new PAT with Repo access
>   - It is recommended that this is a service account user
>   - Note: This user/bot will need to have access to push to your repo's default branch. This can be configured in the branch protection rules.
> - Add the PAT as an Actions [Organization secret](https://github.com/organizations/salesforcecli/settings/secrets/actions)
>   - Set the `Name` to `SVC_CLI_BOT_GITHUB_TOKEN`
>   - Paste in your new PAT as the `Value`
>   - Set `Repository Access` to 'Selected Repositories'
>   - Click the gear icon to select repos that need access to the PAT
>     - This can be edited later
>   - Click `Add Secret`

## Opinionated publish process for npm

> github is the source of truth for code AND releases. Get the version/tag/release right on github, then publish to npm based on that.

![](./images/plugin-release.png)

1. work on a feature branch, commiting with conventional-commits
2. merge to main
3. A push to main produces (if your commits have `fix:` or `feat:`) a bumped package.json and a tagged github release via `githubRelease`
4. A release cause `npmPublish` to run.

Just need to publish to npm? You could use any public action to do step 4.
Use this repo's `npmPublish` if you need either

1. codesigning for Salesforce CLIs
2. integration with CTC
   or if you own other repos that need those features and just want consistency.

### githubRelease

> creates a github release based on conventional commit prefixes. Using commits like `fix: etc` (patch version) and `feat: wow` (minor version).
> A commit whose **body** (not the title) contains `BREAKING CHANGES:` will cause the action to update the packageVersion to the next major version, produce a changelog, tag and release.

```yml
name: create-github-release

on:
  push:
    branches: [main]

jobs:
  release:
    uses: llmzy/github-workflows/.github/workflows/create-github-release.yml@main
    secrets: inherit
    # you can also pass in values for the secrets
    # secrets:
    #  SVC_CLI_BOT_GITHUB_TOKEN: gh_pat00000000
```

#### Controlling Changelog Date Range

You can now control how far back your changelog history goes by specifying a cutoff date. By default, all releases are kept in the changelog, but you can limit it to releases since a specific date:

```yml
jobs:
  release:
    uses: llmzy/github-workflows/.github/workflows/create-github-release.yml@main
    secrets: inherit
    with:
      # Only include releases since January 1, 2023 in the changelog
      first-release-date: "2023-01-01" 
```

This feature automatically counts the number of semver-compliant releases (git tags) since the specified date and passes the appropriate `release-count` to the changelog generator. This approach provides a cleaner way to maintain changelog history compared to manually setting a fixed release count.

### npmPublish

> This will verify that the version has not already been published. There are additional params for signing your plugin and integrating with Change Traffic Control (release moratoriums) that you probably only care about if your work for Salesforce.

example usage

```yml
on:
  release:
    # the result of the githubRelease workflow
    types: [published]

jobs:
  my-publish:
    uses: llmzy/github-workflows/.github/workflows/npmPublish.yml
    with:
      tag: latest
      githubTag: ${{ github.event.release.tag_name }}
    secrets: inherit
    # you can also pass in values for the secrets
    # secrets:
    #  NPM_TOKEN: ^&*$
```

### Publishing to GitHub Packages

When using workflows that install packages from GitHub Packages (like `@llmzy/release-management`), you need to configure the registry and scope. Here are examples for all workflows:

#### For npmPublish workflow

```yml
jobs:
  my-publish:
    uses: llmzy/github-workflows/.github/workflows/npmPublish.yml
    with:
      tag: latest
      githubTag: ${{ github.event.release.tag_name }}
      publishToGithubPackages: true
      scope: "@myorg"
    secrets: inherit
    # When publishing to GitHub Packages, you need the SVC_CLI_BOT_GITHUB_TOKEN secret
    # secrets:
    #  SVC_CLI_BOT_GITHUB_TOKEN: ${{ secrets.SVC_CLI_BOT_GITHUB_TOKEN }}
```

### Plugin Signing

Plugins created by Salesforce teams can be signed automatically with `sign:true` if the repo is in [salesforcecli](https://github.com/salesforcecli) or [forcedotcom](https://github.com/forcedotcom) gitub organization.

You'll need the CLI team to enable your repo for signing. Ask in <https://salesforce-internal.slack.com/archives/C0298EE05PU>

Plugin signing is not available outside of Salesforce. Your users can add your plugin to their allow list (`unsignedPluginAllowList.json`)

```yml
on:
  release:
    # the result of the githubRelease workflow
    types: [published]

jobs:
  my-publish:
    uses: llmzy/github-workflows/.github/workflows/npmPublish.yml
    with:
      sign: true
      tag: latest
      githubTag: ${{ github.event.release.tag_name }}
    secrets: inherit
```

### Prereleases

`main` will release to `latest`. Other branches can create github prereleases and publish to other npm dist tags.

You can create a prerelease one of two ways:

1. Create a branch with the `prerelease/**` prefix. Example `prerelease/my-fix`
   1. Once a PR is opened, every commit pushed to this branch will create a prerelease
   2. The default prerelease tag will be `dev`. If another tag is desired, manually set it in your `package.json`. Example: `1.2.3-beta.0`
1. Manually run the `create-github-release` workflow in the Actions tab
   1. Click `Run workflow`
      1. Select the branch you want to create a prerelease from
      1. Enter the desired prerelease tag: `dev`, `beta`, etc

> [!NOTE]  
> Since conventional commits are used, there is no need to manually remove the prerelease tag from your `package.json`. Once the PR is merged into `main`, conventional commits will bump the version as expected (patch for `fix:`, minor for `feat:`, etc)

Setup:

1. Configure the branch rules for wherever you want to release from
1. Modify your release and publish workflows like the following

```yml
name: create-github-release

on:
  push:
    branches:
      - main
      # point at specific branches, or a naming convention via wildcard
      - prerelease/**
    tags-ignore:
      - "*"
  workflow_dispatch:
    inputs:
      prerelease:
        type: string
        description: "Name to use for the prerelease: beta, dev, etc. NOTE: If this is already set in the package.json, it does not need to be passed in here."

jobs:
  release:
    uses: llmzy/github-workflows/.github/workflows/create-github-release.yml@main
    secrets: inherit
    with:
      prerelease: ${{ inputs.prerelease }}
      # If this is a push event, we want to skip the release if there are no semantic commits
      # However, if this is a manual release (workflow_dispatch), then we want to disable skip-on-empty
      # This helps recover from forgetting to add semantic commits ('fix:', 'feat:', etc.)
      skip-on-empty: ${{ github.event_name == 'push' }}
```

```yml
name: publish

on:
  release:
    # both release and prereleases
    types: [published]
  # support manual release in case something goes wrong and needs to be repeated or tested
  workflow_dispatch:
    inputs:
      tag:
        description: github tag that needs to publish
        type: string
        required: true

jobs:
  # parses the package.json version and detects prerelease tag (ex: beta from 4.4.4-beta.0)
  getDistTag:
    outputs:
      tag: ${{ steps.distTag.outputs.tag }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.release.tag_name || inputs.tag  }}
      - uses: llmzy/github-workflows/.github/actions/getPreReleaseTag@main
        id: distTag

  npm:
    uses: llmzy/github-workflows/.github/workflows/npmPublish.yml@main
    needs: [getDistTag]
    with:
      tag: ${{ needs.getDistTag.outputs.tag || 'latest' }}
      githubTag: ${{ github.event.release.tag_name || inputs.tag }}
    secrets: inherit
```

### Publishing from multiple long-lived branches

> In this example `main` publishes to npm on a 1.x.x version and uses `latest`. `some-other-branch` publishes version 2.x.x and uses the `v2` dist tag

```yml
name: version, tag and github release

on:
  push:
    # add the other branch so that it causes github releases just like main does
    branches: [main, some-other-branch]

jobs:
  release:
    uses: llmzy/github-workflows/.github/workflows/githubRelease.yml@main
    secrets: inherit
```

```yml
on:
  release:
    # the result of the githubRelease workflow
    types: [published]

jobs:
  my-publish:
    uses: llmzy/github-workflows/.github/workflows/npmPublish.yml
    with:
      # ternary-ish https://github.com/actions/runner/issues/409#issuecomment-752775072
      # if the version is 2.x we release it on the `v2` dist tag
      tag: ${{ startsWith( github.event.release.tag_name || inputs.tag, '1.') && 'latest' || 'v2'}}
      githubTag: ${{ github.event.release.tag_name }}
    secrets: inherit
```

## Opinionated Testing Process

Write unit tests to tests units of code (a function/method).

Write not-unit-tests to tests larger parts of code (a command) against real environments/APIs.

Run the UT first (faster, less expensive for infrastructure/limits).

```yml
name: tests
on:
  push:
    branches-ignore: [main]
  workflow_dispatch:

jobs:
  unit-tests:
    uses: llmzy/github-workflows/.github/workflows/unitTest.yml@main
  nuts:
    needs: unit-tests
    uses: llmzy/github-workflows/.github/workflows/nut.yml@main
    secrets: inherit
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
      fail-fast: false
    with:
      os: ${{ matrix.os }}
```

## Other Tooling

### nut conditional on commit message

```yml
# conditional nuts based on commit message includes a certain string
sandbox-nuts:
  needs: [nuts, unit-tests]
  if: contains(github.event.push.head_commit.message,'[sb-nuts]')
  uses: llmzy/github-workflows/.github/workflows/nut.yml@main
  secrets: inherit
  with:
    command: test:nuts:sandbox
    os: ubuntu-latest
```

### externalNut

> Scenario
>
> 1. you have NUTs on a plugin that uses a library
> 2. you want to check changes to the library against those NUTs

see <https://github.com/forcedotcom/source-deploy-retrieve/blob/>> e09d635a7b852196701e71a4b2fba401277da313/.github/workflows/test.yml#L25 for an example

### automerge

> This example calls the automerge job. It'll merge PRs from dependabot that are
>
> 1. up to date with main
> 2. mergeable (per github)
> 3. all checks have completed and none failed (skipped may not have run)

```yml
name: automerge
on:
  workflow_dispatch:
  schedule:
    - cron: "56 2,5,8,11 * * *"

jobs:
  automerge:
    uses: llmzy/github-workflows/.github/workflows/automerge.yml@main
    with:
      registryUrl: 'https://npm.pkg.github.com'
      scope: '@llmzy'
    # secrets are needed
    secrets: inherit
```

need squash?

```yml
automerge:
  with:
    mergeMethod: squash
```

### versionInfo

> requires npm to exist. Use in a workflow that has already done that
>
> given an npmTag (ex: `7.100.0` or `latest`) returns the numeric version (`foo` => `7.100.0`) plus > the xz linux tarball url and the short (7 char) sha.
>
> Intended for releasing CLIs, not for general use on npm packages.

```yml
# inside steps
- uses: llmzy/github-workflows/.github/actions/versionInfo@main
  id: version-info
  with:
    version: ${{ inputs.version }}
    npmPackage: sfdx-cli
- run: echo "version is ${{ steps.version-info.outputs.version }}
- run: echo "sha is ${{ steps.version-info.outputs.sha }}
- run: echo "url is ${{ steps.version-info.outputs.url }}
```

### validatePR

> Checks that PRs have a link to a github issue OR a GUS WI in the form of `@W-12456789@` (the `@` are to be compatible with [git2gus](https://github.com/forcedotcom/git2gus))

```yml
name: pr-validation

on:
  pull_request:
    types: [opened, reopened, edited]
    # only applies to PRs that want to merge to main
    branches: [main]

jobs:
  pr-validation:
    uses: llmzy/github-workflows/.github/workflows/validatePR.yml@main
```

### prNotification

> Mainly used to notify Slack when Pull Requests are opened.
>
> For more info see [.github/actions/prNotification/README.md](.github/actions/prNotification/README.md)

```yaml
name: Slack Pull Request Notification

on:
  pull_request:
    types: [opened, reopened]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Notify Slack on PR open
        env:
          WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
          PULL_REQUEST_AUTHOR_ICON_URL: ${{ github.event.pull_request.user.avatar_url }}
          PULL_REQUEST_AUTHOR_NAME: ${{ github.event.pull_request.user.login }}
          PULL_REQUEST_AUTHOR_PROFILE_URL: ${{ github.event.pull_request.user.html_url }}
          PULL_REQUEST_BASE_BRANCH_NAME: ${{ github.event.pull_request.base.ref }}
          PULL_REQUEST_COMPARE_BRANCH_NAME: ${{ github.event.pull_request.head.ref }}
          PULL_REQUEST_NUMBER: ${{ github.event.pull_request.number }}
          PULL_REQUEST_REPO: ${{ github.event.pull_request.head.repo.name }}
          PULL_REQUEST_TITLE: ${{ github.event.pull_request.title }}
          PULL_REQUEST_URL: ${{ github.event.pull_request.html_url }}
        uses: llmzy/github-workflows/.github/actions/prNotification@main
```

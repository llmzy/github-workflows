# Count Releases Since Date

A GitHub Action that counts the number of semver-compliant releases (git tags) that have been created since a specified date.

## Use Cases

- Maintaining changelogs that include only releases since a specific date
- Configuring the `release-count` parameter for changelog generators
- Tracking release velocity over time

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `cutoff-date` | Date in YYYY-MM-DD format from which to count releases | Yes | - |
| `default-count` | Default count to return if the cutoff date is invalid or no releases are found | No | `0` |
| `tag-prefix` | Optional prefix for semver tags (e.g., "v") | No | `` (empty string) |

## Outputs

| Name | Description |
|------|-------------|
| `release-count` | Number of semver-compliant releases (git tags) since the cutoff date |

## Usage

### Basic usage

```yaml
- name: Count releases since date
  id: release-count
  uses: llmzy/github-workflows/.github/actions/countReleasesSinceDate@main
  with:
    cutoff-date: '2023-01-01'
```

### With all parameters

```yaml
- name: Count releases since date
  id: release-count
  uses: llmzy/github-workflows/.github/actions/countReleasesSinceDate@main
  with:
    cutoff-date: '2023-01-01'
    default-count: '10'
    tag-prefix: 'v'
```

### Using with conventional-changelog-action

```yaml
- name: Count releases since date
  id: release-count
  uses: llmzy/github-workflows/.github/actions/countReleasesSinceDate@main
  with:
    cutoff-date: '2023-01-01'

- name: Generate changelog
  uses: TriPSs/conventional-changelog-action@v3
  with:
    github-token: ${{ secrets.github_token }}
    release-count: ${{ steps.release-count.outputs.release-count }}
    # Other parameters...
```

## Testing Locally

You can test the action locally using the provided test script:

```bash
# Navigate to the action directory
cd .github/actions/countReleasesSinceDate

# Run the test script
./test-action.sh
```

The test script will:

1. Create a temporary git repository with tags at various dates
2. Run several test cases against the release counting logic
3. Display the results and clean up

## Notes

- Only counts tags that follow semantic versioning (e.g., `1.0.0`, `v2.3.1`, `3.0.0-beta.1`)
- The date comparison uses ISO format (`YYYY-MM-DD`) for reliable sorting
- If no releases are found since the cutoff date, the action returns the `default-count` value
- When using with `tag-prefix`, only tags with that exact prefix will be counted

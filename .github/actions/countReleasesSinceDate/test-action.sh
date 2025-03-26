#!/bin/bash
set -e

# Colors for output
GREEN="\033[0;32m"
RED="\033[0;31m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

# Function to print colored output
print_colored() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

# Function to create a test repo with tags at different dates
create_test_repo() {
  print_colored $BLUE "Creating test repository with semver tags..."
  
  mkdir -p test-repo
  cd test-repo
  git init

  # Configure Git
  git config user.name "Test User"
  git config user.email "test@example.com"
  
  # Create an initial commit
  echo "# Test Repository" > README.md
  git add README.md
  git commit -m "Initial commit"
  
  # Create tags with different dates
  # Note: We use GIT_COMMITTER_DATE to force specific dates

  # 2021 releases
  echo "Update 1" >> README.md
  git add README.md
  GIT_COMMITTER_DATE="2021-01-15T12:00:00" git commit --date="2021-01-15T12:00:00" -m "Update 1"
  GIT_COMMITTER_DATE="2021-01-15T12:00:00" git tag -a "1.0.0" -m "v1.0.0"
  
  echo "Update 2" >> README.md
  git add README.md
  GIT_COMMITTER_DATE="2021-06-20T12:00:00" git commit --date="2021-06-20T12:00:00" -m "Update 2"
  GIT_COMMITTER_DATE="2021-06-20T12:00:00" git tag -a "1.1.0" -m "v1.1.0"
  
  # 2022 releases
  echo "Update 3" >> README.md
  git add README.md
  GIT_COMMITTER_DATE="2022-01-10T12:00:00" git commit --date="2022-01-10T12:00:00" -m "Update 3"
  GIT_COMMITTER_DATE="2022-01-10T12:00:00" git tag -a "v1.2.0" -m "v1.2.0"
  
  echo "Update 4" >> README.md
  git add README.md
  GIT_COMMITTER_DATE="2022-07-05T12:00:00" git commit --date="2022-07-05T12:00:00" -m "Update 4"
  GIT_COMMITTER_DATE="2022-07-05T12:00:00" git tag -a "1.3.0-beta.1" -m "v1.3.0-beta.1"
  
  # 2023 releases
  echo "Update 5" >> README.md
  git add README.md
  GIT_COMMITTER_DATE="2023-02-15T12:00:00" git commit --date="2023-02-15T12:00:00" -m "Update 5"
  GIT_COMMITTER_DATE="2023-02-15T12:00:00" git tag -a "1.3.0" -m "v1.3.0"
  
  echo "Update 6" >> README.md
  git add README.md
  GIT_COMMITTER_DATE="2023-09-30T12:00:00" git commit --date="2023-09-30T12:00:00" -m "Update 6"
  GIT_COMMITTER_DATE="2023-09-30T12:00:00" git tag -a "2.0.0" -m "v2.0.0"
  
  # 2024 releases
  echo "Update 7" >> README.md
  git add README.md
  GIT_COMMITTER_DATE="2024-03-01T12:00:00" git commit --date="2024-03-01T12:00:00" -m "Update 7"
  GIT_COMMITTER_DATE="2024-03-01T12:00:00" git tag -a "v2.1.0" -m "v2.1.0"
  
  # Add a non-semver tag as well
  echo "Non-semver update" >> README.md
  git add README.md
  GIT_COMMITTER_DATE="2024-04-01T12:00:00" git commit --date="2024-04-01T12:00:00" -m "Non-semver update"
  GIT_COMMITTER_DATE="2024-04-01T12:00:00" git tag -a "not-semver" -m "Not a semver tag"
  
  # Verify tags were created correctly
  echo "Verifying tags..."
  git tag -l
  
  print_colored $GREEN "Created repository with 8 tags (7 semver, 1 non-semver) across 2021-2024"
  cd ..
}

# Function to count releases since a date (adapted from the GitHub Action)
count_releases() {
  local cutoff_date=$1
  local default_count=${2:-0}
  local tag_prefix=${3:-""}
  
  cd test-repo
  
  echo "Using cutoff date: $cutoff_date"
  
  # Validate date format
  if ! [[ $cutoff_date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "::warning::Invalid date format. Expected YYYY-MM-DD, got $cutoff_date. Using default count: $default_count"
    echo $default_count
    cd ..
    return
  fi
  
  # Debug - show all available tags with dates
  echo "DEBUG: All available tags with dates:"
  git for-each-ref --sort=-creatordate --format="%(creatordate:iso) %(refname:short)" refs/tags
  
  # Get all semver tags sorted by date and count those after the cutoff
  # Using a simple approach with grep
  if [ -n "$tag_prefix" ]; then
    # Only match tags with the exact prefix
    matching_tags=$(git for-each-ref --sort=creatordate --format="%(creatordate:iso) %(refname:short)" refs/tags | 
                    grep "^2" | # Only lines starting with date (2xxx year)
                    grep -E "${tag_prefix}[0-9]+\.[0-9]+\.[0-9]+" | # Match semver format with prefix
                    awk -v date="$cutoff_date" '$1 >= date {print}')
  else
    # Match with or without v prefix
    matching_tags=$(git for-each-ref --sort=creatordate --format="%(creatordate:iso) %(refname:short)" refs/tags | 
                   grep "^2" | # Only lines starting with date (2xxx year)
                   grep -E "[0-9]+\.[0-9]+\.[0-9]+" | # Match any semver format
                   awk -v date="$cutoff_date" '$1 >= date {print}')
  fi
  
  # Count matching tags
  if [ -z "$matching_tags" ]; then
    count=0
  else
    count=$(echo "$matching_tags" | wc -l)
    count=$(echo "$count" | tr -d '[:space:]') # Trim whitespace
  fi
  
  # Debug output
  echo "Semver tags since $cutoff_date:"
  echo "$matching_tags"
  echo "----------"
  echo "Found $count semver releases since $cutoff_date"
  
  # If no releases found, use the default
  if [ "$count" -eq "0" ]; then
    echo "No semver releases found since cutoff date, using default count: $default_count"
    count="$default_count"
  fi
  
  cd ..
  
  echo $count
}

# Function to run tests
run_tests() {
  print_colored $BLUE "\nRunning tests on the action..."
  
  # Define test cases: [description, cutoff date, expected count, tag prefix]
  test_cases=(
    "All releases:2020-01-01:7:"
    "Releases since 2022:2022-01-01:5:"
    "Releases since 2023:2023-01-01:3:"
    "Releases since 2024:2024-01-01:1:"
    "Future date:2025-01-01:0:"
    "Invalid date:INVALID:0:"
    "With v prefix:2020-01-01:2:v"
  )
  
  total_tests=${#test_cases[@]}
  passed_tests=0
  
  for test_case in "${test_cases[@]}"; do
    IFS=':' read -r description cutoff_date expected_count tag_prefix <<< "$test_case"
    
    print_colored $YELLOW "\nTEST: $description"
    echo "Cutoff date: $cutoff_date, Expected count: $expected_count, Tag prefix: $tag_prefix"
    
    result=$(count_releases "$cutoff_date" "0" "$tag_prefix")
    
    # Extract the last line as the result
    actual_count=$(echo "$result" | tail -n 1)
    
    if [ "$actual_count" == "$expected_count" ]; then
      print_colored $GREEN "✅ PASSED: Got expected count $actual_count"
      ((passed_tests++))
    else
      print_colored $RED "❌ FAILED: Expected $expected_count, got $actual_count"
    fi
  done
  
  echo ""
  if [ $passed_tests -eq $total_tests ]; then
    print_colored $GREEN "ALL TESTS PASSED: $passed_tests/$total_tests tests"
  else
    print_colored $RED "SOME TESTS FAILED: $passed_tests/$total_tests tests passed"
  fi
}

# Clean up resources
cleanup() {
  print_colored $BLUE "\nCleaning up..."
  if [ -d "test-repo" ]; then
    rm -rf test-repo
    print_colored $GREEN "Test repository deleted"
  fi
}

# Main execution
main() {
  print_colored $BLUE "==== Testing countReleasesSinceDate Action ===="
  
  # Create test repo
  create_test_repo
  
  # Run the tests
  run_tests
  
  # Clean up
  cleanup
  
  print_colored $BLUE "==== Testing Complete ===="
}

# Run the main function
main 
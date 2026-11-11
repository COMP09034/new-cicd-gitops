# Part 1: The Commit Stage

The **commit stage** is the first phase of a pipeline. It runs on every commit, giving developers fast feedback (ideally under five minutes) and stopping broken or insecure code from progressing.

Typical activities: compile, unit tests, static analysis and vulnerability scanning.

## 1.1 Run the Steps Locally

Always verify locally before automating.

### Build and test

```bash
./gradlew test
```

You should see `BUILD SUCCESSFUL`. For per-test detail, open the HTML report at `build/reports/tests/test/index.html` (summary, packages, classes, and stack traces for failures).

### Vulnerability scan with Grype

Vulnerable dependencies are a major security risk, so we scan for them early. **Grype** matches your dependencies against known CVE databases.

```bash
# Install
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
grype version

# Scan the project
grype .
```

Results are grouped by severity: **Critical**, **High**, **Medium**, **Low**, **Negligible**. Critical and High should be fixed first.

To scan built artifacts as well:

```bash
./gradlew build
grype build/libs
```

## 1.2 Automate with GitHub Actions

A **workflow** is a YAML file in `.github/workflows/` that runs **jobs** (on a fresh runner VM) made of **steps** in response to **events** such as `push`.

Create `.github/workflows/commit-stage.yml`:

```yaml
name: Commit Stage

on:
  push:
  workflow_dispatch:

permissions:
  contents: read
  security-events: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source code
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v3

      - name: Build and test
        run: ./gradlew build

      - name: Install Grype
        run: curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

      - name: Scan for vulnerabilities
        run: grype . --fail-on high -o sarif --file results.sarif

      - name: Upload vulnerability report
        if: success() || failure()
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: results.sarif
```

Key points:

- `permissions` - `contents: read` allows checkout; `security-events: write` allows publishing scan results to the repository's **Security** tab.
- `./gradlew build` compiles, runs the tests and packages the JAR. Any failing step fails the job and skips later steps.
- `--fail-on high` fails the build if a High or Critical vulnerability is found.
- `if: success() || failure()` uploads the SARIF report even when the scan fails, so you can inspect the findings.

Commit and push, then check the **Actions** tab. All steps should be green.

## 1.3 Trigger a Vulnerability Alert

To see the scan working, add a known-vulnerable dependency to `build.gradle`:

```groovy
implementation 'org.apache.logging.log4j:log4j-core:2.14.1' // Vulnerable dependency for teaching purposes
```

This Log4j version is affected by **Log4Shell (CVE-2021-44228)**, one of the most severe vulnerabilities ever discovered, trivially exploitable remotely.

Commit and push, then:

1. Observe the failed scan step in **Actions**
2. Review the findings in the repository's **Security** tab

**Now remove the dependency**, commit, and confirm the pipeline is green again before moving on.

---

[← Back to README](./README.md) | [Next: Part 2 - The Package Stage →](./Part2.md)

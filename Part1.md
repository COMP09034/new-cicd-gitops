# Part 1: The Commit Stage

The **commit stage** is the first phase of a pipeline. It runs on every commit, giving developers fast feedback (ideally under five minutes) and stopping broken or insecure code from progressing.

Typical activities: compile, unit tests, static analysis and vulnerability scanning. In this part you'll focus on building and testing, then add a vulnerability scan as a security gate.

## 1.1 Run the Steps Locally

Always verify locally before automating. The pipeline will run exactly the same commands.

### Build

```bash
./gradlew build
```

This compiles the code, runs all tests, and packages the application as a JAR in `build/libs/`. If any step fails, Gradle stops and reports `BUILD FAILED`.

### Test

To run only the tests:

```bash
./gradlew test
```

You should see `BUILD SUCCESSFUL`. Tests pass when all assertions hold and no unexpected exceptions occur. They fail when an assertion doesn't match or an exception is thrown.

For per-test detail, open the HTML report at `build/reports/tests/test/index.html`. It shows pass/fail counts, results by class, execution times, and full stack traces for failures.

To run a subset of tests:

```bash
./gradlew test --tests *Controller
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
```

Key points:

- `on: push` runs the workflow on every push; `workflow_dispatch` also lets you run it manually from the **Actions** tab.
- `permissions: contents: read` is the minimum needed to check out the code.
- Each job runs on a fresh VM, so the workflow must check out the code and install Java itself.
- `setup-gradle` caches dependencies between runs to keep the stage fast.
- `./gradlew build` compiles, runs the tests and packages the JAR. If any step fails, the job fails and later steps are skipped.

Commit and push, then check the **Actions** tab. All steps should be green.

## 1.3 Break the Build

The commit stage is a quality gate. Prove it works by making a test fail.

1. Pick an existing test and change an expected value so the assertion is wrong
2. Run `./gradlew test` locally and open the HTML report to find the failure and its stack trace
3. Commit and push, then open the failed run in **Actions** and find the same failure in the log
4. Revert the change, push again, and confirm the pipeline is green

Broken code is caught within minutes of the commit, and nothing after this stage will run for it.

## 1.4 Add a Security Gate

Tests check that the code works. We should also check that its dependencies are safe. **Grype** matches your dependencies against known CVE databases, and results are graded **Critical**, **High**, **Medium**, **Low** or **Negligible**.

Try it locally:

```bash
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
grype .
```

Now add these steps to the end of the `build` job in `commit-stage.yml`:

```yaml
      - name: Install Grype
        run: curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

      - name: Scan for vulnerabilities
        run: grype . --fail-on high
```

`--fail-on high` fails the build if a High or Critical vulnerability is found.

To see it working, add a known-vulnerable dependency to `build.gradle`:

```groovy
implementation 'org.apache.logging.log4j:log4j-core:2.14.1' // Vulnerable dependency for teaching purposes
```

This Log4j version is affected by **Log4Shell (CVE-2021-44228)**, one of the most severe vulnerabilities ever discovered, trivially exploitable remotely.

Commit and push, then open the failed **Scan for vulnerabilities** step in **Actions** and review the findings.

**Now remove the dependency**, commit, and confirm the pipeline is green again before moving on.

---

[← Back to README](./README.md) | [Next: Part 2 - The Package Stage →](./Part2.md)

<img src="./atuLogo2.jpg" height="200" align="centre"/>

# ATU Cloud Native Computing

# Lab: CI/CD and GitOps for the Catalog Service

## Introduction

A deployment pipeline automates the journey of code from commit to production. In this lab you'll build one for the `catalog-service` Spring Boot application, from a first commit through to a running deployment on Kubernetes.

The pipeline answers three questions in turn:

| Stage | Question | Tooling |
|-------|----------|---------|
| Commit | Does the code work and is it safe? | Gradle, Grype, GitHub Actions |
| Package | Can we package it for deployment? | Docker, GitHub Container Registry (GHCR) |
| Deploy | Can we deploy it reliably and repeatably? | Kubernetes, ArgoCD (GitOps) |

```
 git push ──► Commit Stage ──► Package Stage ──► GitOps Deploy
              build, test,     container image    ArgoCD syncs
              vuln scan        pushed to GHCR     Git state to cluster
```

## Lab Objectives

By the end of this lab you will:

- Run build, test and vulnerability scans locally, then automate them with GitHub Actions
- Package the application as a container image and push it to GHCR with traceable tags
- Deploy to Kubernetes using GitOps with ArgoCD
- Understand how the stages combine into a complete pipeline (Build → Release → Run)

## Prerequisites
- JDK 21, Docker, and `git`
- A local Kubernetes cluster (e.g. Docker Desktop with Kubernetes enabled) and `kubectl` (needed for Part 3)
The repository contains the application source, a `Dockerfile`, and Kubernetes manifests in `k8s/
`.
- You'll be given the `<ORG>` and `<REPO>` values used later, which you can fill in the "Your Values" table in Part 2.

## Lab Structure

1. [Part 1: The Commit Stage](./Part1.md) - build, test and scan locally and in GitHub Actions
2. [Part 2: The Package Stage](./Part2.md) - build and publish container images
3. [Part 3: GitOps Deployment with ArgoCD](./Part3.md) - deploy the image to Kubernetes

Work through the parts in order. Each part builds on the previous one.

# Quick Start Guide

Get up and running with `sem` in under five minutes.

## Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0) or later
- An Azure AD account with `Application.Read.All` permission in the tenants you want to monitor

## Step 1: Install

```bash
dotnet tool install -g SecretsExpirationMonitor
```

Verify:

```bash
sem --version
```

## Step 2: Add a tenant

```bash
sem tenant add xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx "Contoso"
```

The first argument is your Azure AD **Tenant ID** (a GUID — find it in the Azure Portal under *Azure Active Directory → Overview*).

## Step 3: Run the monitor

```bash
sem monitor
```

On first run you will see a device code prompt:

```
To sign in, use a web browser to open the page https://microsoft.com/devicelogin
and enter the code XXXXXXXXX to authenticate.
```

Open the URL, enter the code, and sign in with an account that has `Application.Read.All`. The token is cached locally — subsequent runs are silent.

## Step 4: Review results

Secrets are shown in a color-coded table:

| Color | Meaning |
|---|---|
| Cyan | Expiring, but plenty of time |
| Yellow | Getting close |
| Orange | Urgent |
| Red | Critical or already expired |

Add `--detailed` for a per-tenant count summary:

```bash
sem monitor --detailed
```

## Managing tenants

```bash
sem tenant list
sem tenant remove "Contoso"
```

## Adjusting the threshold

By default secrets expiring within **90 days** are shown. Change it:

```bash
sem config set --threshold 60
sem config show
```

## All commands

```
sem monitor [--tenant <name>] [--threshold <days>] [--detailed]
sem tenant add <tenant-id> <name>
sem tenant remove <name-or-id>
sem tenant list
sem config show
sem config set [--threshold <days>]
```

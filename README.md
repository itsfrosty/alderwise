# Alderwise

<p align="center">
  <img src="https://github.com/itsfrosty/alderwise/blob/main/logo.png" width="200">
</p>

**See where your money goes, without giving up your privacy.**

Alderwise brings your money into one calm, organized place on your Mac, so it is easier to understand your spending and stay in control.

Import your financial history, review what needs attention, and keep your financial life local. Private by design, with no bank linking and no required account.

> **Status:** Alderwise is pre-release. There is no public build yet. The first public build will appear in [GitHub Releases](https://github.com/itsfrosty/alderwise/releases). If you want to follow launch, watch this repository.

## See Alderwise in Action

<!-- Replace this block with a screenshot of the Home view -->
> Screenshot placeholder: Home dashboard with month-to-date spending, pace, and pressure points at a glance.

<!-- Replace this block with a screenshot of the import flow -->
> Screenshot placeholder: Import screen showing which files are ready, which account each one belongs to, and what needs fixing first.

<!-- Replace this block with a screenshot of the Review view -->
> Screenshot placeholder: Review screen for approving suggested categories and turning decisions into reusable rules.

<!-- Replace this block with a screenshot of the rules and targets view -->
> Screenshot placeholder: Rules and targets view for managing monthly goals, reusable rules, and the transactions behind each number.

## What You Can Do

- Import one or many bank and card CSV files into a single local workspace.
- Repair column mappings before import when a file needs attention.
- Review uncertain transactions instead of hiding ambiguity behind silent automation.
- Build a cleaner ledger with reusable local rules, starter classifications, and optional local suggestions.
- Track monthly targets for the categories you care about most.
- Keep backups and recovery workflows on your Mac.

## How It Works

1. Export a CSV from your bank, credit card, or other financial account.
2. Import it into Alderwise and assign it to the right account in your workspace.
3. Fix any blocked mappings before import.
4. Review suggested classifications and save reusable rules from the decisions you make.
5. Use the resulting ledger to inspect transactions, track targets, and understand where your money is going.

## Why It Feels Different

Many personal finance tools begin with account linking, background syncing, and a remote service that becomes the system of record.

Alderwise takes a more deliberate approach:

- you export data from your bank or card provider yourself
- you keep one local workspace on your Mac
- you stay in the loop when a transaction needs review
- you can save reusable rules from your review decisions over time
- you get a clearer view of spending without turning the product into a constant corrective workflow

## Why It Stays Private

Alderwise is a native macOS app built around a local workspace.

- Alderwise does not ask for bank credentials. You bring your own CSV exports.
- The current workflow does not require an Alderwise account, bank connection, or cloud sync service.
- The app stores its workspace locally on your Mac at `~/Library/Application Support/Alderwise/workspace.sqlite`.
- Backup and restore are local features. By default, backups are created as SQLite files in a `Backups` folder next to the workspace.
- Local suggestions can be turned on or off in Settings, and review remains part of the workflow for ambiguous transactions.
- This README is describing the current local workflow. It is not claiming third-party security audits, app-level encryption, or a broader security model beyond what is documented here.

## Who It’s For

Alderwise is built for people who:

- prefer CSV imports over account-linking services
- want a native Mac app instead of a browser dashboard
- care about privacy and local control
- want help organizing spending without giving up review
- like automation, but still want the final say

## Available on macOS

- macOS 15+
- Native macOS app
- Local workspace stored on your machine

## Follow the Project

If you want to follow the project, report a problem, or share what you want from a local-first finance app, open an [issue](https://github.com/itsfrosty/alderwise/issues).

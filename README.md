# Mute Player By Account

Allows players to be muted by Steam account; basically the mute equivalent of `sm_addban`.  Simple database, too.

## Installation

1.  Run the init script located at `configs/sql-init-scripts/mute_account.sql`.  I think it should be fine with SQLite, but it is built and tested with SQL in mind.
2.  Add a `muted_accounts` entry to your `configs/databases.cfg`.
3.  Compile and install the plugin.

## Usage

```
sm_muteid <time> <steamid> [reason]
```
The syntax is the same as `sm_addban`; none of the arguments need to be enclosed in quotes.

Supports Steam2 and Steam3 formatted IDs.

Permanent mutes can also be applied by setting the time to 0.

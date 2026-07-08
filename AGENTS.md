# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`simp-ima` is a SIMP Puppet module that manages the Linux kernel's **Integrity
Measurement Architecture (IMA)** on Enterprise Linux systems. It has three
public entry points:

- **`ima`** (`manifests/init.pp`) — turns IMA on/off via kernel boot parameters
  (`ima`, `ima_audit`, `ima_template`, `ima_hash`, `ima_tcb`) and mounts the
  `securityfs` when IMA is already active on the running kernel.
- **`ima::policy`** (`manifests/policy.pp`) — renders `/etc/ima/policy.conf`
  from a template and wires it into a boot-time loader (a systemd unit or a
  SysV init script), so a custom IMA measurement/appraisal policy is applied.
- **`ima::appraise`** (`manifests/appraise.pp`) — manages IMA **appraisal**
  (the `ima_appraise` / `ima_appraise_tcb` kernel parameters), driving a
  multi-reboot `fix` → relabel → `enforce` workflow that labels the filesystem
  with `security.ima` extended attributes.

Everything IMA-relevant is applied through kernel boot parameters, so **almost
every change requires a reboot** to take effect. The module signals this with
`reboot_notify` resources rather than rebooting on its own.

### Business logic

Five classes total: three public (`ima`, `ima::policy`, `ima::appraise`) and two
private (`ima::appraise::fixmode`, `ima::appraise::relabel`, both
`assert_private()`'d).

- **`ima` (`manifests/init.pp:42-130`)** — public entry class (consumers
  `include 'ima'`). Parameters (`init.pp:42-50`): `$enable` (`Boolean`, default
  `true`), `$mount_dir` (`Stdlib::AbsolutePath`, default
  `/sys/kernel/security`), `$ima_audit` (`Boolean`, default `false`),
  `$ima_template` (`Ima::Template`, default `'ima-ng'`), `$ima_hash`
  (`String[1]`, default `'sha256'`), `$ima_tcb` (`Boolean`, default `true`),
  `$log_max_size` (`Integer[1]`, default `30000000`).
  - When `$enable`: the `securityfs` `mount` is declared **only if the running
    kernel already has `ima=on`** (`$facts['cmdline']['ima'] == 'on'`,
    `init.pp:54`). `kernel_parameter { 'ima' }` is set to `'on'`
    (`init.pp:68-71`) and `ima_audit` to `'1'`/`'0'` (`init.pp:73-80`).
  - `ima_template`/`ima_hash` are only set when
    `versioncmp($facts['kernelmajversion'], '3.13') >= 0`; otherwise they are
    ensured `absent` (`init.pp:82-97`) — the docstring notes the template is
    fixed to `ima` on older kernels.
  - `ima_tcb` is only declared when `$ima_tcb` is true (`init.pp:99-104`).
  - **IMA log-size guard** (`init.pp:106-112`): if the `ima_log_size` fact
    (custom, this module) is `>= $log_max_size`, a `reboot_notify { 'ima_log' }`
    is raised telling the operator to reboot to clear the in-kernel measurement
    log.
  - When `!$enable`, `ima`/`ima_audit`/`ima_template`/`ima_hash`/`ima_tcb` are
    all ensured `absent` (`init.pp:114-119`).
  - `reboot_notify { 'ima_reboot' }` subscribes to all five kernel parameters
    (`init.pp:121-129`).

- **`ima::policy` (`manifests/policy.pp:79-226`)** — public; `include '::ima'`
  (`policy.pp:113`). One boolean per filesystem/SELinux context to exclude from
  measurement (all default `true`), plus `$dont_watch_list` (extra SELinux
  contexts, `policy.pp:105`) and `measure_*` / `appraise_fowner` toggles (all
  default `false`, `policy.pp:106-110`). Two lookup tables — `$magic_hash`
  (fsmagic numbers, `policy.pp:116-128`) and `$sel_hash` (SELinux log types,
  `policy.pp:130-144`) — feed the ERB template.
  - When `$manage` (`policy.pp:146`): creates `/etc/ima` (`0750`) and
    `/etc/ima/policy.conf` (`0640`, rendered from
    `${module_name}/ima_policy.conf.erb`). If the node's `init_systems` fact
    includes `systemd` it installs `import_ima_rules.service` (enabled but
    `ensure => stopped`) and hardlinks the policy to
    `/etc/ima/ima-policy.systemd` via an `exec` (`policy.pp:161-180`); otherwise
    it installs the SysV `/etc/init.d/import_ima_rules` script (`policy.pp:181-192`).
  - `exec { 'load_ima_policy' }` (`policy.pp:194-202`) cats the policy into
    `/sys/kernel/security/ima/policy` — but **only when the running kernel
    already has `ima=on`** and only as a `refreshonly` subscriber to the policy
    file.
  - When `!$manage` (`policy.pp:204-225`): removes the loader unit/script and
    disables the service.

- **`ima::appraise` (`manifests/appraise.pp:72-169`)** — public; `include
  '::ima'` (`appraise.pp:79`). Parameters (`appraise.pp:72-78`): `$enable`
  (default `true`), `$relabel_file` (default
  `${facts['puppet_vardir']}/simp/.ima_relabel`), `$scriptdir` (default
  `/usr/local/bin`), `$force_fixmode` (default `false`), `$ensure_packages`
  (`Simplib::PackageEnsure`, default via `simplib::lookup` — see the seam
  section below).
  - When `$enable`: installs `attr` and `ima-evm-utils`, sets
    `ima_appraise_tcb` and `rootflags=i_version` kernel parameters, and
    installs `${scriptdir}/ima_security_attr_update.sh` (`appraise.pp:81-108`).
  - **State machine** (`appraise.pp:111-151`): if `$force_fixmode`, delegate to
    `ima::appraise::fixmode` (no relabel). Otherwise branch on
    `$facts['cmdline']['ima_appraise']`: `'fix'` → `ima::appraise::relabel`;
    `'off'` → `fixmode` with relabel; `'enforce'` → remove the relabel file;
    default → if `ima_appraise_tcb` is on the cmdline treat as enforce (remove
    relabel file), else `fixmode` with relabel.
  - When `!$enable`: `ima_appraise`/`ima_appraise_tcb` ensured `absent` and the
    update script removed (`appraise.pp:153-162`).
  - `reboot_notify { 'ima_appraise_reboot' }` subscribes to
    `Kernel_parameter['ima_appraise_tcb']` (`appraise.pp:164-168`).

- **`ima::appraise::fixmode` (`manifests/appraise/fixmode.pp:3-34`)** — private
  (`assert_private()`, `fixmode.pp:7`). Sets `ima_appraise=fix` and, per its
  `$relabel` parameter, creates or removes the relabel-trigger file; notifies
  `reboot_notify { 'ima_appraise_fix_reboot' }`.

- **`ima::appraise::relabel` (`manifests/appraise/relabel.pp:25-66`)** — private
  (`assert_private()`, `relabel.pp:29`). Branches on the `ima_security_attr`
  fact (custom, this module): `'inactive'` → set `ima_appraise=enforce`, rebuild
  initramfs (`dracut -f`), notify enforce reboot; `'active'` → warn that the
  relabel script is still running (do not reboot); default (`need_relabel`) →
  launch `${scriptdir}/ima_security_attr_update.sh` in the background.

### Gotchas / non-obvious details

- **Almost nothing takes effect without a reboot.** IMA is configured through
  kernel boot parameters; the module raises `reboot_notify` and expects the
  operator to reboot. Multiple reboots are required to walk appraisal from
  `fix` → `enforce`.
- **The `securityfs` mount and live policy load are conditional on the running
  kernel.** Both `mount { $mount_dir }` (`init.pp:54`) and the `load_ima_policy`
  exec (`policy.pp:194`) only fire when `$facts['cmdline']['ima'] == 'on'` — on
  a fresh node where IMA was just enabled but not yet rebooted, these resources
  are simply not declared this run.
- **`ima::policy` renders a "dont_watch" policy by default.** Every
  `dont_watch_*` boolean defaults to `true`, so the generated `policy.conf`
  excludes the standard pseudo-filesystems and SELinux log types from
  measurement. The `measure_*` and `appraise_fowner` toggles all default to
  `false` (`policy.pp:106-110`).
- **The template must contain no stray newlines.** `ima_policy.conf.erb` opens
  with `<% # There can be no newlines in this file -%>` and uses trailing-hyphen
  ERB tags throughout; preserve that when editing.
- **`ima::appraise::relabel` runs the labeling script in the background** (`&`,
  `relabel.pp:55`) and relies on the `ima_security_attr` fact to detect whether
  it is still running (`lib/facter/ima_security_attr.rb` greps `ps -ef`). Do not
  assume the relabel completes within one Puppet run.
- **Two custom facts gate behavior and are confined at the OS level:**
  `ima_log_size` (`lib/facter/ima_log_size.rb`) is confined to hosts where
  `/sys/kernel/security/ima/ascii_runtime_measurements` exists; `ima_security_attr`
  (`lib/facter/ima_security_attr.rb`) is confined to hosts whose `cmdline` has
  `ima_appraise_tcb`. On other hosts these facts are unset and the guarded
  branches are skipped.
- **Duplicated docstrings in `init.pp`.** The `@param ima_tcb` and
  `@param log_max_size` blocks each appear twice (`init.pp:24-30` and
  `init.pp:32-40`) — harmless, but only edit them once each when updating docs.
- **`measure_module_check` has no `@param` description** (`policy.pp:75` lists it
  with no text); it is still a real parameter used by the template
  (`ima_policy.conf.erb:33-35`).
- **`ima::appraise::relabel::scriptdir` reads `$ima::appraise::scriptdir`**
  (`relabel.pp:27`) as its default — the private class depends on the public
  `ima::appraise` class variable being set, which holds because `appraise.pp`
  is the only caller.

## The `simp_options` / `simplib::lookup` seam

This module has a **single, minimal** `simp_options` seam — it is not the
lookup-heavy module the `fips` template describes. There is exactly one
`simplib::lookup` call:

| Line | Key | `default_value` |
|------|-----|-----------------|
| `manifests/appraise.pp:77` | `simp_options::package_ensure` | `'installed'` |

The `ima`, `ima::policy`, and the two private classes do **not** consume the
`simp_options` seam at all. There is also **no module data layer** — the repo
has no `hiera.yaml` and no `data/` directory, so all defaults live directly in
the class parameter lists. If you add SIMP feature toggles, route them through
`simplib::lookup('simp_options::*', { 'default_value' => ... })` with an explicit
default, matching `appraise.pp:77`.

## Dependencies

Module dependencies (from `metadata.json`):

- `puppet/augeasproviders_grub` `>= 3.1.0 < 7.0.0` (provides the
  `kernel_parameter` type/provider used throughout)
- `simp/simplib` `>= 4.9.0 < 6.0.0` (provides `simplib::lookup`, `reboot_notify`,
  and the `init_systems` fact used in `policy.pp`)
- `puppetlabs/stdlib` `>= 8.0.0 < 10.0.0` (provides `member()`, used in
  `policy.pp:161,206`)

No optional dependencies are declared (`metadata.json` has no
`simp.optional_dependencies`).

Fixture-only dependencies (from `.fixtures.yml`, present for test compilation,
not runtime deps): `augeasproviders_core`, `mount_core` (the `puppetlabs/mount`
core provider, needed to test the `mount` resource), plus the runtime deps
above. Note **`simp_options` is not even a fixture** here — the sole
`simp_options::package_ensure` lookup falls through to its default in tests.

Runtime requirement (from `metadata.json` `requirements`): `openvox
>= 8.0.0 < 9.0.0`.

Supported OS matrix (from `metadata.json`): CentOS 9/10; RedHat 8/9/10;
OracleLinux 8/9/10; Rocky 8/9/10; AlmaLinux 8/9/10. (No Amazon Linux.)

## Repository layout

- `manifests/init.pp` — the `ima` class (kernel params, securityfs mount, log
  guard).
- `manifests/policy.pp` — the `ima::policy` class (renders `policy.conf`, wires
  the boot-time loader).
- `manifests/appraise.pp` — the `ima::appraise` class (appraisal state machine).
- `manifests/appraise/fixmode.pp`, `manifests/appraise/relabel.pp` — private
  helper classes for the appraisal workflow.
- `types/template.pp` — `Ima::Template = Enum['ima','ima-ng','ima-sig']`, the
  only custom data type.
- `lib/facter/ima_log_size.rb`, `lib/facter/ima_security_attr.rb` — the two
  custom facts (see gotchas). No custom Puppet types/providers or functions.
- `templates/ima_policy.conf.erb` — the IMA policy file template (newline-
  sensitive).
- `files/import_ima_rules.service`, `files/import_ima_rules`,
  `files/ima_security_attr_update.sh` — the systemd unit, SysV init script, and
  relabel helper shipped via `source => puppet:///modules/...`.
- `metadata.json` — deps, OS matrix, OpenVox requirement. **No `hiera.yaml` or
  `data/`.**
- `spec/classes/{init,policy,appraise}_spec.rb`,
  `spec/classes/appraise/{fixmode,relabel}_spec.rb` — rspec-puppet unit tests.
- `spec/unit/facter/{ima_log_size,ima_security_attr}_spec.rb` — fact unit tests.
- `spec/files/*.conf` — expected rendered-policy fixtures compared in
  `policy_spec.rb`.
- `spec/acceptance/suites/default/00_ima_spec.rb` — beaker acceptance suite;
  nodesets under `spec/acceptance/nodesets/`.
- `REFERENCE.md` — generated Puppet Strings reference; `README.md` — narrative
  docs.
- **Acceptance runs in CI:** `.github/workflows/pr_tests.yml` has an
  `acceptance` job (matrix `almalinux9`, `almalinux10`) whose final step runs
  `bundle exec rake beaker:suites[default,<node>]` under
  `BEAKER_HYPERVISOR=vagrant_libvirt`.

## Common commands

```sh
# Install dependencies
bundle install

# Run all unit tests
bundle exec rake spec

# Run a single class spec
bundle exec rspec spec/classes/policy_spec.rb

# Run the fact unit tests
bundle exec rspec spec/unit/facter/ima_log_size_spec.rb

# Puppet lint
bundle exec rake lint

# Ruby lint
bundle exec rake rubocop

# Regenerate REFERENCE.md from puppet-strings docstrings
puppet strings generate --format markdown --out REFERENCE.md

# Run the default beaker acceptance suite
bundle exec rake beaker:suites[default]
```

Relevant gem pins (from `Gemfile`): `puppetlabs_spec_helper ~> 8.0.0`,
`simp-rake-helpers ~> 5.24.0`, `simp-rspec-puppet-facts ~> 4.0.0`,
`simp-beaker-helpers ~> 2.0.0`. Rubocop is pinned to `~> 1.88.0`. The `:test`
group loads **both** the `openvox` and `puppet` gems (defaulting to `>= 8 < 9`)
during the Puppet → OpenVox migration.

## Conventions

- Preserve the `@summary` / `@param` puppet-strings docstrings on the classes —
  they drive `REFERENCE.md`. Regenerate `REFERENCE.md` after changing docs or
  parameters.
- Keep the IMA policy template (`ima_policy.conf.erb`) free of stray newlines;
  use trailing-hyphen ERB tags as the existing template does.
- Guard kernel- and filesystem-state-dependent resources on facts (as
  `$facts['cmdline']['ima']`, `ima_log_size`, and `ima_security_attr` do) rather
  than assuming a target state; the module reflects and steers boot state across
  reboots, it does not force it in one run.
- Keep the private appraisal helpers (`fixmode`, `relabel`) `assert_private()`'d
  and only reachable through `ima::appraise`.
- Route any new SIMP feature toggles through
  `simplib::lookup('simp_options::*', { 'default_value' => ... })`, matching
  `appraise.pp:77`.
- `Gemfile`, `.gitignore`, `.pdkignore`, and `.github/workflows/pr_tests.yml`
  carry a **puppetsync** notice — they are baseline-managed and the next sync
  overwrites local edits. Push changes to those files upstream to the baseline,
  not here.
- Match the existing 2-space Puppet indentation and aligned-arrow parameter
  style used in the manifests.

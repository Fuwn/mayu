# ⭐ Mayu

> Moe-Counter Compatible Website Hit Counter

Mayu is a drop-in replacement for [Moe-Counter](https://github.com/journey-ad/Moe-Counter). It
serves the same counter routes and reads Moe-Counter's existing SQLite database.

Mayu commits every hit to the database as it arrives, so a crashed or killed process loses no
counts. On one CPU, Mayu served 4,165 SVG counters per second while saving every hit. Moe-Counter
served 317 per second when it also saved every hit. With every theme loaded, an idle Mayu container
uses 45 MiB of memory. An idle container from Moe-Counter's official image uses 90 MiB. Mayu's
Docker image is 66 MB compressed, and Moe-Counter's is 84 MB.

Mayu is written in [Gleam](https://gleam.run) and stores counters in [SQLite](https://sqlite.org)
or [PostgreSQL](https://www.postgresql.org).

<br>

<img src="https://mayu.due.moe/get/@demo" width="50%">

<img src="https://mayu.due.moe/get/@demo?theme=urushi" width="50%">

<br>

## Usage

The `theme` query parameter of a `get` request selects the theme, for example
[mayu.due.moe/get/@demo?theme=urushi](https://mayu.due.moe/get/@demo?theme=urushi).

This repository tracks four original themes: `garukura`, `lain`, `urushi`, and `yuruyuri`.
`./scripts/sync-themes.sh` adds the rest of the [Moe-Counter](https://github.com/journey-ad/Moe-Counter)
theme collection, including `asoul`, `gelbooru`, `moebooru`, and `rule34`. The Docker image runs
the script at build time; run it yourself after cloning to get the full set locally.

The script fetches the upstream revision pinned inside it and copies only files that are missing
locally. It never replaces or deletes local files. To copy from a local upstream checkout instead,
pass its path as the first argument.

Mayu pads the count with leading zeroes to 6 digits. The `padding` query parameter of a `get`
request changes this, up to a maximum of 12.

### Local

```bash
$ git clone git@github.com:Fuwn/mayu.git
$ cd mayu
$ gleam run
```

With Nix, `nix develop` provides the Gleam, Erlang, and rebar3 toolchain.

### Docker

```shell
docker run --volume 'mayu:/mayu/data/' -p '80:3000' --rm fuwn/mayu:latest
```

The named volume, `mayu`, keeps the SQLite database across container restarts. PostgreSQL
deployments do not need it, because the data lives in the database server.

Mayu listens on port `3000` unless `PORT` is set, and binds every interface over both IPv4 and IPv6.

### Database

By default, Mayu stores counters in SQLite at `data/count.db`, relative to the working directory.
In the Docker image, that is `/mayu/data/count.db`.

To use PostgreSQL instead, set `MAYU_DATABASE_URL` to a `postgres://` or `postgresql://` URL, for
example `postgres://mayu:secret@localhost:5432/mayu`. Add `?sslmode=require` if your provider
requires TLS. Mayu creates its table on start-up, so an empty database is enough.

Mayu uses Moe-Counter's table layout. To keep existing counts, copy Moe-Counter's database file to
`data/count.db` before starting Mayu.

On start-up, Mayu adds `created_at` and `updated_at` columns if the table lacks them. The `record`
route returns these timestamps; counters that existed before the columns were added report an empty
`created_at`.

### Configuration

Mayu reads its configuration from environment variables. All of them are optional.

| Variable | Description |
| --- | --- |
| `PORT` | Port the server listens on. Defaults to `3000`. |
| `MAYU_DATABASE_URL` | A `postgres://` or `postgresql://` URL. When unset, Mayu uses the SQLite file at `data/count.db`. |
| `MAYU_THEMES` | Comma-separated list of themes to load, for example `asoul,garukura`. When unset, Mayu loads every theme. A shorter list uses less memory and lowers the largest possible response. |
| `MAYU_PRUNE_MIN_COUNT` | Counters with fewer than this many hits are eligible for pruning. |
| `MAYU_PRUNE_AFTER_DAYS` | Counters not incremented within this many days are eligible for pruning. |
| `MAYU_PRUNE_EVERY_HOURS` | How often, in hours, the prune sweep runs. |

Pruning runs only when all three `MAYU_PRUNE_*` variables are positive integers. Each sweep deletes
a counter only if it has fewer than `MAYU_PRUNE_MIN_COUNT` hits *and* no hits within
`MAYU_PRUNE_AFTER_DAYS` days. A counter that meets just one of those conditions stays.

### Routes

- `/` serves the homepage, which builds embed snippets for a counter.
- `/get/@name` increments counter `name` and returns it as an `image/svg+xml` image. It accepts the
  `theme` and `padding` query parameters. Without a valid `theme`, Mayu uses `asoul` if it is loaded,
  otherwise the first loaded theme in alphabetical order whose name does not end in `-h`.
- `/record/@name` increments counter `name` and returns its `name`, `num`, `created_at`, and
  `updated_at` as JSON.
- `/heart-beat` returns `alive`.

Counter names must be 1 to 64 characters long. The `demo` counter always shows 1234567890 and is
never stored. Any other path redirects to this repository.

## Checks

`gleam test` runs the SQLite and request tests.

`MAYU_TEST_DATABASE_URL=postgres://postgres@localhost:5432/mayu_test gleam run -m postgres_test`
runs the PostgreSQL tests. They work in a temporary schema inside a transaction, then roll the
transaction back so the database keeps its previous state.

`python3 test/http_smoke.py http://localhost:3000` checks a running instance, including
concurrent increments. It creates a counter, so point it at a disposable database. CI runs it
against the built container.

## Resource Attributions

- [A-SOUL_Official](https://space.bilibili.com/703007996)
- [Moebooru](https://github.com/moebooru/moebooru)
- [Rule 34](https://rule34.xxx) (NSFW)
- [Gelbooru](https://gelbooru.com) (NSFW)
- [Urushi](https://x.com/udon0531/status/1350738347681959936)
- [Lain Iwakura](https://x.com/lililjiliijili/status/869722811236929538)
- [GaruKura](https://www.pixiv.net/artworks/119693017)

## Licence

This project is licensed under the [GNU General Public License v3.0](LICENSE).

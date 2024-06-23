# ⭐ Mayu

> Moe-Counter Compatible Website Hit Counter

Mayu is a drop-in replacement for [Moe-Counter](https://github.com/journey-ad/Moe-Counter) designed
to be lightweight and easy to use.

Mayu is written in [Gleam](https://gleam.run) and uses [SQLite](https://sqlite.org) as its database.

<br>

<img src="https://counter.due.moe/get/@demo" width="50%">

<img src="https://counter.due.moe/get/@demo?theme=urushi" width="50%">

<br>

Don't know Gleam or functional paradigms? Take a look at the [source tree](./src) and see just how
easy it is to understand! It's all contained in under 300 (294) liberally newline'd lines of code!

## Usage

Mayu currently has seven available themes selectable using the `theme` query parameter of any `get` operation.

E.g., [counter.due.moe/get/@demo?theme=urushi](https://counter.due.moe/get/@demo?theme=urushi)

- `asoul`
- `gelbooru-h` (NSFW)
- `gelbooru`
- `moebooru-h` (NSFW)
- `moebooru`
- `rule34` (NSFW)
- `urushi`.

### Local

```bash
$ git clone git@github.com:Fuwn/mayu.git
$ cd mayu
$ gleam run
$ # or
$ nix run
```

### Docker

```shell
docker run --volume 'mayu:/mayu/data/' -p '80:3000' --rm fuwn/mayu:latest
```

This Docker command uses a named volume, `mayu`, which allows the Mayu's database to persist between container restarts.

### Database

Mayu will use SQLite by default and will place the database file, `count.db`, within the `data/` directory of the project's root directory.

Mayu has the same default database layout as Moe-Counter, so if you've already used Moe-Counter previously, Mayu will work off of any previously accumulated counter data, so long as you transfer the database file over.

Mayu additionally adds two database columns: `created_at` and `updated_at`, which will not affect standard operations in any way, but will allow for additional data to be available should you perform a `record` operation.

### Routes

- `/heart-beat`: `alive`
- `/get/@name`: An `image/xml+svg` counter, defaulting to theme `asoul`, modifiable using the `theme` query parameter
- `/record/@name`: JSON object containing the database's `name`, `num`, `created_at`, and `updated_at` fields for counter `name`

## Resource Attributions

- [A-SOUL_Official](https://space.bilibili.com/703007996)
- [Moebooru](https://github.com/moebooru/moebooru)
- [Rule 34](https://rule34.xxx) (NSFW)
- [Gelbooru](https://gelbooru.com) (NSFW)
- [Urushi](https://x.com/udon0531/status/1350738347681959936)
- [Lain Iwakura](https://x.com/lililjiliijili/status/869722811236929538)

## Licence

This project is licensed with the [GNU General Public License v3.0](LICENSE).

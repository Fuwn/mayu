# ⭐ Mayu

> Moe-Counter Compatible Website Hit Counter

Mayu is a drop-in replacement for [Moe-Counter](https://github.com/journey-ad/Moe-Counter) designed
to be lightweight and easy to use.

Mayu is written in [Gleam](https://gleam.run) and uses [SQLite](https://sqlite.org) as its database.

<br>

![](https://counter.due.moe/get/@demo)

![](https://counter.due.moe/get/@demo?theme=urushi)

## Usage

### Local

```bash
$ git clone git@github.com:Fuwn/mayu.git
$ cd mayu
$ gleam run
```

### Docker

```shell
docker run --volume 'mayu:/mayu/data/' -p '80:3000' --rm fuwn/mayu:latest
```

### Database

Mayu will use SQLite by default and will place the database file, `count.db`, within the `data/` directory of the project's root directory.

## Resource Attributions

- [A-SOUL_Official](https://space.bilibili.com/703007996)
- [Moebooru](https://github.com/moebooru/moebooru)
- [Rule 34](https://rule34.xxx) (NSFW)
- [Gelbooru](https://gelbooru.com) (NSFW)

## Licence

This project is licensed with the [GNU General Public License v3.0](LICENSE).

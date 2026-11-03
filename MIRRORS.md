# Repository mirrors

EscClose is maintained in two repositories:

| Platform | Repository | Role |
| --- | --- | --- |
| GitHub | <https://github.com/alchemy7746/esc-close> | Primary repository |
| Gitee | <https://gitee.com/alchemy_star/wx-esc-close> | Mirror |

## Remotes

The local repository uses:

```text
origin  git@github.com:alchemy7746/esc-close.git
gitee   git@gitee.com:alchemy_star/wx-esc-close.git
```

## Push a release

```bash
git push origin main
git push origin --tags
git push gitee main
git push gitee --tags
```

GitHub Actions builds and publishes the release after a `v*` tag is pushed. Gitee does not run the GitHub workflow; upload the generated `dist/EscClose-*.zip` to the equivalent Gitee Release manually.

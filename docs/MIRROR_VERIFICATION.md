# Verificación del mirror automático

Este documento describe cómo comprobar que el espejo bidireccional GitHub ⇄ GitLab funciona.

## Arquitectura

| Dirección | Mecanismo | Secreto necesario |
|---|---|---|
| GitHub → GitLab | `.github/workflows/mirror-to-gitlab.yml` (GitHub Actions) | `GITLAB_TOKEN` en los secretos del repo de GitHub |
| GitLab → GitHub | `.gitlab-ci.yml` (GitLab CI) | `GH_TOKEN` como variable CI en GitLab |

Ambos trabajos:

1. obtienen todo el historial;
2. comparan el SHA local con el SHA remoto;
3. si son iguales, omiten el push (evita bucles);
4. si el remoto es ancestors del local, hacen un push normal;
5. si las ramas divergieron, fallan y avisan en lugar de hacer `force-push`.

## Prueba 1: GitHub → GitLab

```bash
echo "verify $(date -u +%FT%TZ)" >> docs/MIRROR_CHECKS.md
git add docs/MIRROR_CHECKS.md
git commit -m "ci: verify GitHub to GitLab mirror"
git push origin main

gh run watch                       # espera a que termine el workflow
git ls-remote https://gitlab.com/BENDER_5000/fail2ban-setup.git refs/heads/main
git rev-parse HEAD                 # debe coincidir con el SHA anterior
```

## Prueba 2: GitLab → GitHub

```bash
echo "verify $(date -u +%FT%TZ)" >> docs/MIRROR_CHECKS.md
git add docs/MIRROR_CHECKS.md
git commit -m "ci: verify GitLab to GitHub mirror"
git push gitlab main

# En GitLab: Build > Pipelines (o glab ci status)
# En GitHub: Actions > Mirror GitHub -> GitLab (se ejecutará y omitirá el push)
git ls-remote https://github.com/BENDER35/fail2ban-setup.git refs/heads/main
git rev-parse HEAD                 # debe coincidir con el SHA anterior
```

## Comprobación final

Los tres SHA deben ser idénticos:

```bash
printf 'local   : '; git rev-parse HEAD
printf 'github  : '; git ls-remote https://github.com/BENDER35/fail2ban-setup.git refs/heads/main | awk '{print $1}'
printf 'gitlab  : '; git ls-remote https://gitlab.com/BENDER_5000/fail2ban-setup.git refs/heads/main | awk '{print $1}'
```

## Si un trabajo falla

- `GITLAB_TOKEN is missing`: el secret no está configurado en GitHub. Añade un PAT de GitLab con `write_repository`.
- `GH_TOKEN CI variable is missing`: añade la variable en GitLab → Settings → CI/CD → Variables (masked).
- `diverged`: alguien hizo push en ambos lados antes de que sincronizara. Compara con `git log --oneline --left-right origin/main...gitlab/main` y fusiona manualmente.
- GitLab CI no se ejecuta: revisa que el proyecto tenga runners compartidos habilitados en Settings → CI/CD → Runners.

## Nota sobre bucles

Cuando GitLab empuja a GitHub se dispara el workflow de GitHub Actions, pero éste detecta que GitLab ya tiene el mismo commit y termina sin push. Lo mismo ocurre en sentido inverso. Por eso el espejo es bidireccional sin repetirse infinitamente.

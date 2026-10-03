#!/usr/bin/env bash
# Bringt eine Version auf GitHub: den Stand eines Tags als einen einzigen
# Commit auf dem lokalen Zweig „github-release". Jede Version hat die vorige
# als Eltern; GitHub sieht so eine gerade Folge von Versionen, ohne die
# Entwicklung dazwischen.
#
#   bash publish_tag_to_github.sh <tag>        etwa v0.9.0
#
# Voraussetzungen:
#   git remote add github git@github.com:<benutzer>/<repo>.git
#   in CHANGELOG.md (im Stand des Tags) ein Abschnitt „## <version> …";
#   <version> ist der Tag ohne führendes „v". Daraus wird die
#   Commit-Nachricht.
#
# Autor und Committer ist die GitHub-Adresse ohne Postfach (unten), nicht die
# Adresse aus der git-Konfiguration: Die Commits auf GitHub sind öffentlich.
set -euo pipefail

readonly REMOTE="github"
readonly ZWEIG="github-release"
readonly NAME="Tobias Steinmann"
readonly EMAIL="topse@users.noreply.github.com"

hilfe() {
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
}

abbruch() {
    printf 'Fehler: %s\n' "$1" >&2
    exit 1
}

# ── Prüfen ──────────────────────────────────────────────────────────────

[[ $# -eq 1 ]] || hilfe

readonly TAG="$1"
readonly VERSION="${TAG#v}"

git rev-parse "${TAG}^{commit}" &>/dev/null \
    || abbruch "Tag „${TAG}“ gibt es nicht."

git remote get-url "${REMOTE}" &>/dev/null \
    || abbruch "Remote „${REMOTE}“ fehlt. Anlegen mit: git remote add ${REMOTE} <adresse>"

# ── Stand und Nachricht ─────────────────────────────────────────────────

readonly QUELLE=$(git rev-parse "${TAG}^{commit}")
readonly BAUM=$(git rev-parse "${TAG}^{tree}")

# Der Abschnitt der Version aus CHANGELOG.md, bis zur nächsten Überschrift
# „## ". Ohne Abschnitt keine Veröffentlichung: Wer die Version auf GitHub
# sieht, soll lesen können, was sie bringt.
CHANGELOG=$(git show "${TAG}:CHANGELOG.md" 2>/dev/null) || true
ABSCHNITT=$(awk -v v="${VERSION}" '
    /^## / { drin = ($2 == v); next }
    drin { print }' <<<"${CHANGELOG}" | sed -e '/./,$!d') || true
if [[ -z "${ABSCHNITT}" ]]; then
    if awk -v v="${VERSION}" '/^## / && $2 == v { f = 1 } END { exit !f }' <<<"${CHANGELOG}"; then
        abbruch "Der Abschnitt „## ${VERSION}“ in CHANGELOG.md (Stand ${TAG}) hat keinen Text."
    fi
    abbruch "In CHANGELOG.md (Stand ${TAG}) fehlt der Abschnitt „## ${VERSION}“."
fi
readonly NACHRICHT="moocp ${VERSION}

${ABSCHNITT}"

export GIT_AUTHOR_NAME="${NAME}" GIT_AUTHOR_EMAIL="${EMAIL}"
export GIT_COMMITTER_NAME="${NAME}" GIT_COMMITTER_EMAIL="${EMAIL}"

# ── Zweig für die Veröffentlichung ──────────────────────────────────────

if ! git show-ref --verify --quiet "refs/heads/${ZWEIG}"; then
    # Lokal fehlt der Zweig: nachsehen, ob GitHub schon Versionen hat.
    echo "Zweig „${ZWEIG}“ fehlt lokal, hole ${REMOTE}/main …"
    git fetch "${REMOTE}" main 2>/dev/null || true
    if git show-ref --verify --quiet "refs/remotes/${REMOTE}/main"; then
        echo "Baue „${ZWEIG}“ aus ${REMOTE}/main nach …"
        git update-ref "refs/heads/${ZWEIG}" "$(git rev-parse "${REMOTE}/main")"
    fi
fi

if git show-ref --verify --quiet "refs/heads/${ZWEIG}"; then
    readonly ELTERN=$(git rev-parse "${ZWEIG}")
    readonly ELTERN_BAUM=$(git rev-parse "${ZWEIG}^{tree}")
    [[ "${BAUM}" != "${ELTERN_BAUM}" ]] \
        || abbruch "Der Stand von ${TAG} ist schon veröffentlicht (gleich ${ZWEIG})."
    readonly NEU=$(git commit-tree "${BAUM}" -p "${ELTERN}" -m "${NACHRICHT}")
else
    echo "Lege „${ZWEIG}“ an (erste Version) …"
    readonly NEU=$(git commit-tree "${BAUM}" -m "${NACHRICHT}")
fi

# Nur den Zeiger setzen, ohne Wechsel des Arbeitsstands.
git update-ref "refs/heads/${ZWEIG}" "${NEU}"

# ── Hochladen ───────────────────────────────────────────────────────────

echo "Lade ${TAG} nach ${REMOTE}/main …"
# --force-with-lease: Hat jemand auf GitHub etwas an main geändert, das hier
# nicht bekannt ist, bricht das Hochladen ab, statt es zu überschreiben.
git push "${REMOTE}" "${ZWEIG}:refs/heads/main" --force-with-lease
# Lokal heißt der Tag „github-v0.9.4“ (er zeigt auf den veröffentlichten
# Commit, nicht auf den der Entwicklung), auf GitHub aber „v0.9.4“: Aus dem
# Tag des Releases liest die Update-Prüfung der App die Version
# (lib/update/update.dart), und dafür muss er dem Schema „v<version>“
# folgen.
git tag --force "github-${TAG}" "${NEU}"
git push "${REMOTE}" "refs/tags/github-${TAG}:refs/tags/${TAG}" --force

cat <<EOF

Veröffentlicht: ${TAG} auf ${REMOTE}
  Quelle:  ${QUELLE:0:12}
  Commit:  ${NEU:0:12}
  Zweig:   ${ZWEIG} -> ${REMOTE}/main
  Tag:     github-${TAG} (auf GitHub: ${TAG})

Auf GitHub noch: aus dem Tag ${TAG} ein Release machen und den Installer
anhängen. Beides muss stimmen, sonst findet die Update-Prüfung der App die
Version nicht:

  Tag des Releases:  ${TAG}
  Name der Datei:    moocp_setup_${VERSION}.exe
  kein Entwurf, keine Vorabversion

EOF

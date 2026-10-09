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
# Liegen auf GitHub nach der letzten Version Commits, die nicht von hier
# kommen (etwa aus einer Cloud-Sitzung), setzt die neue Version auf sie auf –
# aber nur, wenn import_from_github.sh sie geholt hat und sie im Tag stecken.
# Sonst bricht das Skript ab und sagt, wie es weitergeht. main auf GitHub
# wird nie überschrieben.
#
# Autor und Committer ist die GitHub-Adresse ohne Postfach (unten), nicht die
# Adresse aus der git-Konfiguration: Die Commits auf GitHub sind öffentlich.
set -euo pipefail

readonly REMOTE="github"
readonly ZWEIG="github-release"
readonly NAME="Tobias Steinmann"
readonly EMAIL="topse@users.noreply.github.com"

hilfe() {
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
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

# ── Stand auf GitHub ────────────────────────────────────────────────────

echo "Hole ${REMOTE}/main …"
# --no-tags: Die Tags auf GitHub heißen wie die eigenen (v0.9.20), zeigen
# aber auf die veröffentlichten Commits; sie dürfen nicht herein.
if git fetch --no-tags --quiet "${REMOTE}" "+refs/heads/main:refs/remotes/${REMOTE}/main" 2>/dev/null; then
    AUF_GITHUB=$(git rev-parse "refs/remotes/${REMOTE}/main")
else
    # Gibt es main auf GitHub noch nicht, meldet ls-remote 2; alles andere
    # heißt, der Stand dort ist unbekannt.
    STATUS=0
    git ls-remote --exit-code "${REMOTE}" refs/heads/main >/dev/null || STATUS=$?
    [[ ${STATUS} -eq 2 ]] || abbruch "${REMOTE}/main lässt sich nicht holen."
    AUF_GITHUB=""
fi
readonly AUF_GITHUB

# Die zuletzt veröffentlichte Version. Fehlt der Zweig lokal, kommt sie von
# GitHub: der jüngste Commit dort mit einem Tag „github-v…", ohne einen
# solchen Tag main selbst.
if git show-ref --verify --quiet "refs/heads/${ZWEIG}"; then
    LETZTE=$(git rev-parse "refs/heads/${ZWEIG}")
elif [[ -n "${AUF_GITHUB}" ]]; then
    if GH_TAG=$(git describe --tags --abbrev=0 --match 'github-v*' "${AUF_GITHUB}" 2>/dev/null); then
        LETZTE=$(git rev-parse "${GH_TAG}^{commit}")
    else
        LETZTE=${AUF_GITHUB}
    fi
    echo "Zweig „${ZWEIG}“ fehlt lokal, nehme ${LETZTE:0:12} von ${REMOTE}/main …"
else
    LETZTE=""
fi
readonly LETZTE

if [[ -n "${LETZTE}" ]]; then
    [[ "${BAUM}" != "$(git rev-parse "${LETZTE}^{tree}")" ]] \
        || abbruch "Der Stand von ${TAG} ist schon veröffentlicht (gleich ${ZWEIG})."
fi

# Die neue Version setzt immer auf den gerade geholten Stand von GitHub auf;
# das Hochladen rückt main dort nur vor.
if [[ -z "${AUF_GITHUB}" || "${AUF_GITHUB}" == "${LETZTE}" ]]; then
    ELTERN=${LETZTE}
elif git merge-base --is-ancestor "${LETZTE}" "${AUF_GITHUB}"; then
    # Commits auf GitHub nach der letzten Version: Jeder muss über
    # import_from_github.sh im Tag stecken, erkennbar an der Zeile
    # „GitHub-Commit: <sha>" in einem Commit seiner Geschichte.
    IMPORTIERT=$(git log --grep='^GitHub-Commit: ' --format=%B "${TAG}" -- \
        | sed -n 's/^GitHub-Commit: //p')
    FEHLT=""
    for commit in $(git rev-list "${LETZTE}..${AUF_GITHUB}"); do
        grep -qxF "${commit}" <<<"${IMPORTIERT}" \
            || FEHLT+="$(git log -1 --format='  %h  %s' "${commit}")"$'\n'
    done
    [[ -z "${FEHLT}" ]] || abbruch "Auf GitHub liegen Änderungen an main, die in ${TAG} fehlen:
${FEHLT}
So kommen sie herein:
  1. bash import_from_github.sh
  2. in main: git merge github-import, Konflikte lösen
  3. Tag neu setzen: git tag -f ${TAG}
     (steht er schon auf origin, dort ebenso: git push -f origin ${TAG})
  4. bash publish_tag_to_github.sh ${TAG}"
    echo "Auf ${REMOTE}/main liegen importierte Commits; ${TAG} setzt auf sie auf."
    ELTERN=${AUF_GITHUB}
elif git merge-base --is-ancestor "${AUF_GITHUB}" "${LETZTE}"; then
    abbruch "${REMOTE}/main steht vor der zuletzt veröffentlichten Version (${LETZTE:0:12}): Ein früheres Hochladen ist nicht angekommen, oder main wurde auf GitHub zurückgesetzt. Das ist von Hand anzusehen: git log ${REMOTE}/main..${ZWEIG}"
else
    abbruch "${REMOTE}/main baut nicht auf der zuletzt veröffentlichten Version (${LETZTE:0:12}) auf; main wurde auf GitHub umgeschrieben. Das ist von Hand anzusehen."
fi
readonly ELTERN

# Erst zuweisen, dann readonly: „readonly x=$(…)“ verschluckt einen Fehler,
# und ein leeres NEU machte aus dem Hochladen „:refs/heads/main“ – das
# löschte main auf GitHub.
if [[ -n "${ELTERN}" ]]; then
    NEU=$(git commit-tree "${BAUM}" -p "${ELTERN}" -m "${NACHRICHT}")
else
    echo "Lege „${ZWEIG}“ an (erste Version) …"
    NEU=$(git commit-tree "${BAUM}" -m "${NACHRICHT}")
fi
readonly NEU
[[ -n "${NEU}" ]] || abbruch "Der Commit für ${TAG} ließ sich nicht bauen."

# ── Hochladen ───────────────────────────────────────────────────────────

echo "Lade ${TAG} nach ${REMOTE}/main …"
# Ohne Force: NEU baut auf dem gerade geholten Stand auf. Hat inzwischen
# jemand etwas nach main gebracht, lehnt GitHub ab, statt es zu überschreiben.
git push "${REMOTE}" "${NEU}:refs/heads/main"
# Den Zeiger erst danach setzen, ohne Wechsel des Arbeitsstands: Scheitert
# das Hochladen, bleibt der Zweig beim Stand von GitHub.
git update-ref "refs/heads/${ZWEIG}" "${NEU}"
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

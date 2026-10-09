#!/usr/bin/env bash
# Holt Änderungen, die auf GitHub an main entstanden sind (etwa aus einer
# Cloud-Sitzung), auf den lokalen Zweig „github-import", zum Mergen in main.
#
#   bash import_from_github.sh
#   git merge github-import          (in main)
#
# Auf GitHub ist jede Version ein eigener Commit mit dem Stand eines Tags
# (publish_tag_to_github.sh); mit der Geschichte hier hat sie keinen
# gemeinsamen Vorfahren, ein Merge von github/main ginge also nicht. Das
# Skript baut deshalb jeden neuen Commit nach: gleicher Stand, gleiche
# Nachricht, gleicher Autor, aber statt der Version auf GitHub ist der lokale
# Tag mit demselben Stand der Eltern. Jeder nachgebaute Commit trägt die
# Zeile „GitHub-Commit: <sha>"; daran erkennt publish_tag_to_github.sh, dass
# die Änderung im Tag steckt.
#
# Geändert wird nur der Zweig github-import, und nur, wenn auf GitHub etwas
# Neues liegt; main, github-release, Tags und Arbeitsstand bleiben unberührt.
# Im Zweifel bricht das Skript ab.
set -euo pipefail
# Auch in $(…) abbrechen: Dort laufen zuordnen und nachbauen.
shopt -s inherit_errexit

readonly REMOTE="github"
readonly VERSIONEN="github-release"
readonly ZWEIG="github-import"
readonly SCHLUESSEL="GitHub-Commit"

hilfe() {
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
    exit 1
}

abbruch() {
    printf 'Fehler: %s\n' "$1" >&2
    exit 1
}

# ── Prüfen ──────────────────────────────────────────────────────────────

[[ $# -eq 0 ]] || hilfe

git remote get-url "${REMOTE}" &>/dev/null \
    || abbruch "Remote „${REMOTE}“ fehlt. Anlegen mit: git remote add ${REMOTE} <adresse>"

git show-ref --verify --quiet refs/heads/main \
    || abbruch "Zweig „main“ fehlt."

git show-ref --verify --quiet "refs/heads/${VERSIONEN}" \
    || abbruch "Zweig „${VERSIONEN}“ fehlt: Ohne veröffentlichte Version gibt es nichts, worauf Änderungen von GitHub aufbauen könnten."

# Ein ausgecheckter Zweig darf seinen Zeiger nicht unter dem Arbeitsstand
# verlieren: Der Arbeitsstand sähe danach aus, als nähme er alles zurück.
[[ "$(git symbolic-ref -q HEAD || true)" != "refs/heads/${ZWEIG}" ]] \
    || abbruch "„${ZWEIG}“ ist ausgecheckt. Erst auf einen anderen Zweig wechseln (git switch main)."

# ── Holen ───────────────────────────────────────────────────────────────

echo "Hole ${REMOTE}/main …"
# --no-tags: Die Tags auf GitHub heißen wie die eigenen (v0.9.20), zeigen
# aber auf die veröffentlichten Commits; sie dürfen nicht herein.
git fetch --no-tags "${REMOTE}" "+refs/heads/main:refs/remotes/${REMOTE}/main" \
    || abbruch "${REMOTE}/main lässt sich nicht holen."

readonly AUF_GITHUB=$(git rev-parse "refs/remotes/${REMOTE}/main")
readonly LETZTE=$(git rev-parse "refs/heads/${VERSIONEN}")

if [[ "${AUF_GITHUB}" == "${LETZTE}" ]]; then
    echo "Nichts Neues: ${REMOTE}/main ist die zuletzt veröffentlichte Version."
    if git show-ref --verify --quiet "refs/heads/${ZWEIG}" \
        && ! git merge-base --is-ancestor "${ZWEIG}" main; then
        echo "Hinweis: „${ZWEIG}“ ist noch nicht in main gemergt."
    fi
    exit 0
fi

if ! git merge-base --is-ancestor "${LETZTE}" "${AUF_GITHUB}"; then
    if git merge-base --is-ancestor "${AUF_GITHUB}" "${LETZTE}"; then
        abbruch "${REMOTE}/main steht vor der zuletzt veröffentlichten Version (${LETZTE:0:12}): Ein früheres Hochladen ist nicht angekommen, oder main wurde auf GitHub zurückgesetzt. Das ist von Hand anzusehen."
    fi
    abbruch "${REMOTE}/main baut nicht auf der zuletzt veröffentlichten Version (${LETZTE:0:12}) auf; main wurde auf GitHub umgeschrieben. Das ist von Hand anzusehen."
fi

# ── Nachbauen ───────────────────────────────────────────────────────────

# Neu nachgebaut: GitHub-Commit -> lokaler Commit.
declare -A NACHBAU=()

# Der lokale Commit, der einem Elternteil auf GitHub entspricht: in diesem
# Lauf nachgebaut, eine veröffentlichte Version (lokal ihr Tag ohne
# „github-") oder schon früher importiert.
zuordnen() {
    local eltern="$1" kind="$2" gh_tag tag
    if [[ -n "${NACHBAU[${eltern}]:-}" ]]; then
        echo "${NACHBAU[${eltern}]}"
        return
    fi
    for gh_tag in $(git tag --points-at "${eltern}" --list 'github-v*'); do
        tag="${gh_tag#github-}"
        git rev-parse --verify --quiet "refs/tags/${tag}^{commit}" >/dev/null \
            || abbruch "Zu ${gh_tag} fehlt der Tag ${tag}."
        [[ "$(git rev-parse "${tag}^{tree}")" == "$(git rev-parse "${eltern}^{tree}")" ]] \
            || abbruch "${tag} hat nicht mehr den Stand, der als ${gh_tag} veröffentlicht ist."
        git rev-parse "${tag}^{commit}"
        return
    done
    local frueher
    frueher=$(git log --branches -n 1 --format=%H --grep="^${SCHLUESSEL}: ${eltern}\$")
    [[ -n "${frueher}" ]] && { echo "${frueher}"; return; }
    abbruch "${kind:0:12} baut auf ${eltern:0:12} auf; das ist weder eine veröffentlichte Version noch ein importierter Commit."
}

# Autor, Committer und Zeiten bleiben die vom GitHub-Commit; so ergibt ein
# zweiter Lauf dieselben Commits, und der Zweig rückt nur vor.
nachbauen() {
    local commit="$1" eltern ziel nachricht
    local -a argumente=()
    for eltern in $(git rev-list --parents -n 1 "${commit}" | cut -d' ' -f2-); do
        ziel=$(zuordnen "${eltern}" "${commit}")
        argumente+=(-p "${ziel}")
    done
    nachricht=$(git log -1 --format=%B "${commit}" \
        | git interpret-trailers --no-divider --trailer "${SCHLUESSEL}: ${commit}")
    GIT_AUTHOR_NAME=$(git log -1 --format=%an "${commit}") \
    GIT_AUTHOR_EMAIL=$(git log -1 --format=%ae "${commit}") \
    GIT_AUTHOR_DATE=@$(git log -1 --format=%ad --date=raw "${commit}") \
    GIT_COMMITTER_NAME=$(git log -1 --format=%cn "${commit}") \
    GIT_COMMITTER_EMAIL=$(git log -1 --format=%ce "${commit}") \
    GIT_COMMITTER_DATE=@$(git log -1 --format=%cd --date=raw "${commit}") \
        git commit-tree "${commit}^{tree}" "${argumente[@]}" -m "${nachricht}"
}

NEU=""
for commit in $(git rev-list --reverse --topo-order "${LETZTE}..${AUF_GITHUB}"); do
    NEU=$(nachbauen "${commit}")
    NACHBAU[${commit}]="${NEU}"
done
readonly NEU

# ── Zweig setzen ────────────────────────────────────────────────────────

if git merge-base --is-ancestor "${NEU}" main; then
    echo "Nichts Neues: Was auf ${REMOTE}/main liegt, ist schon in main gemergt."
    exit 0
fi

if git show-ref --verify --quiet "refs/heads/${ZWEIG}"; then
    ALT=$(git rev-parse "refs/heads/${ZWEIG}")
    if [[ "${ALT}" == "${NEU}" ]]; then
        echo "Unverändert: „${ZWEIG}“ hat diesen Stand schon."
        git merge-base --is-ancestor "${ZWEIG}" main \
            || echo "Weiter in main mit: git merge ${ZWEIG}"
        exit 0
    fi
    # Was auf dem alten Zweig liegt und weder im neuen Import noch in main
    # steckt, darf nur ein älterer Import sein – nie eigene Arbeit.
    EIGENE=$(git rev-list --invert-grep --grep="^${SCHLUESSEL}: " "${ALT}" --not "${NEU}" main)
    [[ -z "${EIGENE}" ]] \
        || abbruch "Auf „${ZWEIG}“ liegen Commits, die nicht aus einem Import stammen. Erst in main mergen oder den Zweig von Hand löschen."
fi

git update-ref -m "import_from_github: ${AUF_GITHUB:0:12}" "refs/heads/${ZWEIG}" "${NEU}"

echo
echo "Importiert auf „${ZWEIG}“, noch nicht in main:"
git log --format='  %h  %s' "${NEU}" --not main --
cat <<EOF

Weiter, in main:
  git merge ${ZWEIG}
Danach Tag und Veröffentlichung wie gewohnt; publish_tag_to_github.sh setzt
die nächste Version auf diese Commits auf GitHub auf.
EOF

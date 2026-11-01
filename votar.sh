#!/usr/bin/env bash
# Vota em $EU nos 6 cargos do naoeummapa. Roda no GitHub Actions 2x por hora (:05 e :35);
# a regra do site e 1 voto por hora por cargo, entao a tentativa que cair antes de 60 min e recusada e a outra vale.
set -u
EU="${EU:?defina EU}"
SID="${VOTO_SID:?defina o secret VOTO_SID}"
for c in ver pref dep gov sen pres; do
  r=$(curl -s -m 20 -X POST https://naoeummapa.vercel.app/api/voto \
        -H 'content-type: application/json' \
        -d "{\"u\":\"$EU\",\"a\":\"$EU\",\"s\":\"$SID\",\"c\":\"$c\"}")
  echo "$(TZ=America/Sao_Paulo date '+%F %H:%M') $c $r"
done

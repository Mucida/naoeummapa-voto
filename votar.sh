#!/usr/bin/env bash
# Vota em $EU nos 6 cargos do naoeummapa, 1x em cada hora do relogio.
# O servidor aceita qualquer voto, mas so computa o que vier 60 min ou mais depois do ultimo computado.
# Por isso: espera completar 60 min + MARGEM desde o ultimo voto deste script (ultimo.txt) e, depois de votar,
# confere no ofensiva.json do site se a hora foi computada; se o site atualizou e a hora nao entrou
# (ex.: voto pelo navegador a menos de 60 min), vota de novo na mesma hora.
# Disparado a cada 15 min pelo cron-job.org (workflow_dispatch); a maioria das rodadas so ve que ja votou e sai.
set -u
EU="${EU:?defina EU}"
SID="${VOTO_SID:?defina o secret VOTO_SID}"
ESTADO=ultimo.txt
MARGEM=5            # segundos alem dos 60 min (pouco, para o horario do voto nao ir atrasando hora a hora)
ESPERA_MAX=600      # nao espera mais que 10 min: o disparo seguinte cobre o resto

quando() { TZ=America/Sao_Paulo date -d "@$1" '+%F %H:%M:%S'; }

ult=$(cat "$ESTADO" 2>/dev/null || echo 0)
agora=$(date +%s)
hora_atual=$(( agora / 3600 ))

# ofensiva.json: gerado = quando o site refez os numeros (~20 em 20 min);
# p[EU] = [horas, quanto vale, votos, ultima hora computada (horas desde 1970)]
read -r gerado hora_site < <(curl -s -m 30 "https://naoeummapa.vercel.app/ofensiva.json?t=$agora" \
  | python3 -I -c 'import json,sys; o=json.load(sys.stdin); p=o["p"].get(sys.argv[1]) or [0,0,0,0]; print(o["gerado"], p[3])' "$EU" 2>/dev/null) \
  || { gerado=0; hora_site=0; }
gerado=${gerado:-0}; hora_site=${hora_site:-0}

echo "ultimo voto deste script: $(quando "$ult")  agora: $(quando "$agora")"
echo "site atualizado em $(quando "$gerado"); ultima hora computada: $(quando $(( hora_site * 3600 )))"
if [ "$hora_site" = "$hora_atual" ]; then echo "o site ja computou esta hora, nada a fazer"; exit 0; fi

if [ $(( ult / 3600 )) = "$hora_atual" ]; then
  if [ "$gerado" -lt $(( ult + 120 )) ]; then echo "ja votou nesta hora; o site ainda nao atualizou para conferir"; exit 0; fi
  echo "o voto das $(quando "$ult") nao foi computado (outro voto a menos de 60 min?); votando de novo"
else
  espera=$(( ult + 3600 + MARGEM - agora ))
  if [ "$espera" -gt "$ESPERA_MAX" ]; then echo "faltam ${espera}s para completar 60 min; fica para o proximo disparo"; exit 0; fi
  if [ "$espera" -gt 0 ]; then echo "esperando ${espera}s para completar 60 min"; sleep "$espera"; fi
fi

votou=0; falhou=0; momento=$(date +%s)
for c in ver pref dep gov sen pres; do
  for t in 1 2 3; do
    r=$(curl -s -m 20 -X POST https://naoeummapa.vercel.app/api/voto \
          -H 'content-type: application/json' \
          -d "{\"u\":\"$EU\",\"a\":\"$EU\",\"s\":\"$SID\",\"c\":\"$c\"}") || r="erro de rede"
    echo "$(quando "$(date +%s)") $c tentativa $t: $r"
    case "$r" in *'"ok":true'*) votou=1; continue 2 ;; esac
    [ "$t" -lt 3 ] && sleep 20
  done
  falhou=1
done

[ "$votou" = 1 ] && echo "$momento" > "$ESTADO"
exit "$falhou"   # se algum cargo falhou 3x, a rodada fica vermelha no GitHub (e o GitHub manda e-mail)

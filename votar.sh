#!/usr/bin/env bash
# Vota em $EU nos 6 cargos do naoeummapa, 1x em cada hora do relogio.
# O servidor aceita qualquer voto, mas so computa 1 por hora por cargo; para nao gastar o voto da hora,
# guarda em ultimo.txt quando votou e, se preciso, espera completar 60 min + MARGEM antes de votar de novo.
# Disparado a cada 10 min pelo cron-job.org (workflow_dispatch); a maioria das rodadas so ve que ja votou e sai.
set -u
EU="${EU:?defina EU}"
SID="${VOTO_SID:?defina o secret VOTO_SID}"
ESTADO=ultimo.txt
MARGEM=20           # segundos alem dos 60 min
ESPERA_MAX=600      # nao espera mais que 10 min: o disparo seguinte cobre o resto

hora() { TZ=America/Sao_Paulo date -d "@$1" +%Y%m%d%H; }
quando() { TZ=America/Sao_Paulo date -d "@$1" '+%F %H:%M:%S'; }

ult=$(cat "$ESTADO" 2>/dev/null || echo 0)
agora=$(date +%s)
echo "ultimo voto: $(quando "$ult")  agora: $(quando "$agora")"
if [ "$(hora "$ult")" = "$(hora "$agora")" ]; then echo "ja votou nesta hora, nada a fazer"; exit 0; fi

espera=$(( ult + 3600 + MARGEM - agora ))
if [ "$espera" -gt "$ESPERA_MAX" ]; then echo "faltam ${espera}s para completar 60 min; fica para o proximo disparo"; exit 0; fi
if [ "$espera" -gt 0 ]; then echo "esperando ${espera}s para completar 60 min"; sleep "$espera"; fi

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

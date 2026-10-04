# Áudios Sally — controle de uso (atualizado em 03/10/2026)

> `audio/sally/` está aparado: só ficam as frases referenciadas pelo código
> (25 categorias, ~6 mil wavs). O pack fonte deve ficar fora deste
> repositório; consulte os termos do projeto `crew-chief-autovoicepack`
> antes de redistribuir qualquer WAV.

Legenda: ✅ ligado · 🔶 dá para ligar (com ideia de gatilho) · ❌ nunca (sem dado no jogo).

## 🔶 Dá para ligar (diga quais quer)

- `strategy/stop_complete_go` — alternar com "saída livre" no pit exit.
- `mandatory_pit_stops/pit_crew_ready` — alternativa ao "box in" na entrada do box.
- `penalties` por motivo fino residual (cut_track/stop_go por nome fora do contexto) — motivo exato não vem no dado; contexto (box/largada/azul) + parâmetro de espera já cobrem Real Penalty (`dt`/`sg10`).
- `penalties` contagem regressiva (one_lap_to_serve…) — semântica do parâmetro incerta.
- `lap_times/worsening` — variação de "ritmo piorando".
- `lap_times/sector_all_fast`, setores rápidos avulsos fora do roxo — precisa delta ao vivo do setor atual.
- `lap_times` combinados (`sector1_and_2_are`…) — relatório combinado S1+S2.
- `timings` redundantes (`ahead_is_now`, `gap_behind_decreasing`) — os usados já cobrem.
- `numbers` compostos (`1_01`, `1point0seconds`) — talvez volta exata em 1 clip (transcript a conferir).
- `spotter` nuances (`car_inside/outside`, `clear`, `three_wide_on_inside/outside`) — risco de trocar esquerda/direita.
- `position/expected_*` — previsão de chegada (precisa preditor).
- `tyre` médias inner/outer, `bar`, deltas por eixo — redundantes com o que já fala.
- `fuel` conectores (`for`, `into_the_race`) e galões (unidade US).
- `opponents` resto (aposentadoria, reputação, genéricos) — sem dados.
- `race_time/zero_minutes_left`, `lap_counter/two_to_go` — redundantes com o que já fala.

## ❌ Nunca (sem dado no Assetto Corsa)

Rally (`codriver`, `corners`, `pace_notes`), ovais USA (`frozen_order`, `fc_yellow*`, `lucky_dog`, `wave_around`, `two_to_green`, pace-car), elétricos (`battery`), nomes de pilotos (`watched_opponents`, `rating_*`, `cant_pronounce_name`, `car_number`), DRS/PTP (`overtaking_aids`), licença (`licence`), compostos/desgaste/freios/camber/travada (`compound_*`, `worn_*`, `knackered_*` fora all_round, `cooking_brakes*`, `good_brake_temps`, `locking_*`, `spinning_*`, `*flat_spot*`, `camber_*`), óleo/água do motor, previsão de chuva (`we_expect_*` — sem forecast no jogo; chuva atual, tendências e parada ligadas), furos (`*puncture*`), plano de troca de pneus/combustível no box (`confirm_*`, `will_change_*`, `will_fix_*`, `no_fuel/tyres*`, `disengage/engage_limiter`, `wait*`, `pitstop_request*`), limitador/velocidade de box, setores de bandeira verde, `acknowledge_driver_is_ok*` (sem input de voz), disqualificações específicas, `driver_swaps`, `multiclass` por classe, `incidents` (sistema de pontos), `minutes_you_need*`, formação/largada em fila, `until_start_line`, `the_pace_car*`, `stay_behind*`, `move_to_*`, `pileup*` (sem canto da pista), `on_the_inside/outside_line`, `name_has_gone_off*`.

## ✅ Ligado (resumo)

Spotter (10 linhas + variações), combustível (nível, autonomia, degraus 4/3/2/1 voltas e 10/5/2 min, meio-tanque, crítico, box), gaps (frente/atrás/líder, segundos+metros, tendências), batalha, posição (P1/pole/líder/último/voltas de vantagem), voltas (recorde/boa/tempo, validade, cortes), setores reais do jogo + roxo pessoal, ritmo, pneus (quente/morno/frio, pressão, inner/outer, stint, desgaste %, composto, freios), danos (toque/leve/grave, suspensão, câmbio), motor (óleo/água), clima/chuva, box, bandeiras, pênaltis + stop&go, relógio, largada, push, spin, rant, ERS/bateria, DRS, limitador, xingamento, catálogo.

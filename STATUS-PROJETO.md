# Formulário de status — AC Engineer Sally

**Data da verificação:** 05/10/2026
**Escopo:** código e arquivos locais do projeto, verificações estáticas e evidências da sessão mais recente disponíveis nesta conversa.
**Versão declarada no `manifest.ini`:** 1.0.0
**Estado geral:** núcleo implementado; validação final dentro do Assetto Corsa ainda pendente para eventos de risco, resultado da corrida, expressões visuais e penalidades nativas.

## Como ler os estados

- **Completo no código:** a função está implementada e passou pela inspeção/validação estrutural descrita neste formulário.
- **Parcialmente verificado:** existe evidência em log ou teste, mas ela não cobre todo o comportamento nem confirma a experiência visual ou sonora no jogo.
- **Precisa testar no jogo:** o código existe, porém não há evidência recente suficiente de que o evento foi disparado e apresentado corretamente durante a pilotagem.
- **Limitado por dados externos:** o comportamento depende dos dados que o carro e o CSP realmente expõem.

> “Completo no código” não significa automaticamente “confirmado em corrida”. Logs de criação de áudio, por exemplo, confirmam que a Sally acionou a reprodução, mas não substituem a confirmação de que o piloto ouviu o áudio com volume e momento corretos.

## Resumo executivo

| Área | Estado atual | O que falta para fechar |
|---|---|---|
| Inicialização e estrutura Lua | **Completo no código** | Confirmar abertura sem erro após reiniciar o jogo. |
| Configurações e preferências | **Completo no código** | Confirmar salvamento e restauração de idioma e volumes no jogo. |
| Rádio, fila de falas e legendas | **Completo no código; parcialmente verificado** | Ouvir as chamadas em corrida e verificar sincronização/legibilidade das legendas. |
| Telemetria e comentários locais | **Completo no código; parcialmente verificado** | Conferir gatilhos específicos em uma sessão mais longa e variada. |
| Spotter | **Completo no código** | Testar passagem real pela esquerda, direita, lado a lado e pista livre. |
| Danos e pergunta “está bem?” | **Regra implementada e simulada** | Confirmar no jogo que impactos leves não perguntam e colisão forte/perda total perguntam. |
| Sally 2D e expressões | **Interface implementada; resultado visual pendente** | Verificar transparência, tamanho, foco da pista e troca de expressão durante falas diferentes. |
| Áudios de vitória/posição/fim | **Arquivos e referências conferidos; evento pendente** | Terminar uma corrida e conferir a reação correspondente à posição final. |
| Penalidades nativas | **Leitura dos campos do jogo implementada; validação em pista pendente** | Conferir atribuição, lembrete e cumprimento com penalidades fornecidas pelo Assetto/CSP. |
| Integridade dos arquivos de áudio | **Verificado estaticamente** | Audição manual de uma amostra e confirmação de que os áudios escolhidos são os desejados. |
| IA online | **Removida do fluxo atual** | Nenhuma chave/API é necessária para o funcionamento descrito no README. |
| Commit/publicação das alterações locais | **Publicado no GitHub** | Código, expressões, áudios e documentação publicados na branch `main`; a validação final dentro do jogo continua pendente. |

## Formulário detalhado por componente

### 1. Estrutura e inicialização do app

- **Estado:** completo no código; precisa de confirmação após reinicialização do jogo.
- **Inclui:** ponto de entrada do app, módulos Lua, janela principal e painel/central de corrida.
- **Evidência:** análise estática reconheceu e compilou sintaticamente os 12 arquivos Lua principais após a remoção; referências `require`, ações de UI e campos de reinicialização foram cruzados sem itens faltantes.
- **Ainda conferir:** abrir o Assetto Corsa com CSP, ativar Sally, abrir Ajustes e Central de Corrida e observar se aparece erro no app ou no log.
- **Resultado do teste:** `____________________________________________`.

### 2. Interface, ajustes e preferências

- **Estado:** completo no código; persistência visual ainda precisa de teste manual.
- **Inclui:** idioma Português/Inglês, controles de áudio, avisos, testes do rádio/spotter, catálogo e opções da personagem.
- **Evidência:** ações e elementos de UI foram conferidos contra o ponto de entrada do app; existem configurações locais em `user_settings.ini`.
- **Ainda conferir:** alterar idioma/volume, salvar ou fechar o jogo, abrir novamente e confirmar que as escolhas permanecem. Conferir também se os controles não ficam cortados em resoluções diferentes.
- **Resultado do teste:** `____________________________________________`.

### 3. Rádio, reprodução de áudio e legendas

- **Estado:** sistema implementado; reprodução normal parcialmente observada em sessão.
- **Inclui:** fila de chamadas, prioridade do spotter, cancelamento/expiração de chamadas antigas, volumes separados e legendas vinculadas aos clipes.
- **Evidência estrutural:** as referências de áudio restantes apontam para arquivos existentes; os conjuntos de legendas verificados correspondem aos WAVs das pastas auditadas.
- **Evidência de sessão:** o log de CSP da sessão mais recente registra chamadas de áudio da Sally em categorias normais de telemetria, estratégia e rádio. Não foram encontradas linhas de erro/falha/exceção específicas da Sally nesse log.
- **Limite da evidência:** a criação de eventos de áudio no log não confirma por si só o que foi ouvido pelo piloto nem se toda legenda ficou sincronizada.
- **Ainda conferir:** ouvir chamadas em pista, verificar volume relativo engenheira/spotter, interrupção por spotter e desaparecimento da legenda ao final do clipe.
- **Resultado do teste:** `____________________________________________`.

### 4. Voz local e comentários por telemetria

- **Estado:** completo no código; parcialmente observado.
- **Inclui:** escolha por regras locais de clipes gravados depois de voltas válidas, usando contexto de ritmo e posição, sem chamada a serviço de IA.
- **Evidência:** README descreve o funcionamento sem internet/chave de API; a sessão recente registrou atividade de categorias como combustível, pneus, estratégia, condições e tempos.
- **Ainda conferir:** em treino, qualificação e corrida, confirmar que os comentários só ocorrem depois de volta válida, respeitam os intervalos e não repetem falas excessivamente.
- **Resultado do teste:** `____________________________________________`.

### 5. Telemetria e avisos de engenheira

- **Estado:** recursos implementados; cobertura de sessão parcialmente verificada.
- **Inclui, conforme os dados fornecidos pelo carro/CSP:** combustível e autonomia, pneus (temperatura, pressão, desgaste/vida útil), ritmo e voltas, setores, posição e gaps, clima/chuva, bandeiras, pit, bateria/ERS, DRS e estado do carro.
- **Evidência de sessão:** houve eventos de áudio registrados para combustível, pneus, estratégia, condições e tempos na sessão recente.
- **Ainda conferir:** gatilhos de reserva de combustível; pressão/temperatura em stint; chuva e bandeiras; bateria/ERS e DRS em carro compatível; entradas e saídas de box.
- **Limite:** alguns carros ou servidores não fornecem todos os campos; a ausência de um dado pode impedir o aviso mesmo quando a regra existe.
- **Resultado do teste:** `____________________________________________`.

### 6. Spotter

- **Estado:** lógica implementada; precisão espacial precisa de validação em tráfego real.
- **Inclui:** chamadas para carro à esquerda/direita, proximidade, situação lado a lado, três carros e pista livre, com prioridade sobre relatórios comuns.
- **Evidência:** módulos e clipes do spotter foram verificados; os testes internos de fila e estados não substituem a validação com outro carro na pista.
- **Ainda conferir:** outro carro se aproximando por cada lado, permanecendo ao lado, ultrapassando e deixando a área. Confirmar que “livre” não sai antes do tempo e que esquerda/direita não invertem.
- **Resultado do teste:** `____________________________________________`.

### 7. Colisão, dano e pergunta se o piloto está bem

- **Estado:** regra restrita a impacto relevante implementada; simulação lógica passou; validação em Assetto Corsa pendente.
- **Comportamento esperado:** zebra, salto, saída de pista ou toque leve não devem provocar a pergunta. A pergunta deve ficar reservada para colisão forte ou dano/perda importante do carro.
- **Evidência:** teste de lógica recente cobriu caso leve versus caso grave; o código calcula mudança de dano, queda de velocidade e perda de motor após o evento de colisão.
- **Sessão recente:** não houve evento de dano/colisão que confirmasse a regra em uso real.
- **Ainda conferir:** comparar um toque leve seguro com uma colisão forte em sessão controlada e observar a fala e a expressão escolhida.
- **Resultado do teste:** `____________________________________________`.

### 8. Sally 2D, fundo transparente e expressões

- **Estado:** personagem, prévias e suporte a expressões estão no app; apresentação durante a corrida ainda não foi confirmada na sessão mais recente.
- **Inclui:** imagem da Sally na interface e estados visuais como neutra, brava, focada, alerta e feliz, conforme os recursos presentes no projeto.
- **Evidência:** a interface de ajustes/documentação expõe a prévia de expressões; os arquivos do módulo de avatar e UI existem.
- **Ainda conferir:** se o fundo realmente fica transparente sobre o HUD; se o recorte não cobre a pista ou informação importante; se a expressão muda com a fala correta e volta ao estado neutro quando termina.
- **Ponto de atenção:** a prévia no painel não comprova que o avatar em corrida muda de expressão em todos os gatilhos.
- **Resultado do teste:** `____________________________________________`.

### 9. Final de corrida e reação por posição

- **Estado:** áudio/categorias de resultado e legendas foram inventariados; acionamento em uma chegada recente não foi confirmado.
- **Objetivo previsto:** Sally reagir ao resultado/posição final com a fala apropriada, por exemplo vitória, pódio ou resultado inferior, sem anunciar resultado incorreto.
- **Evidência:** existem WAVs para `finished_race` e `finished_race_last`; as legendas correspondentes foram restauradas e conferidas com os arquivos da pasta.
- **Sessão recente:** não foi registrado evento de fala de resultado/fim que permita confirmar o comportamento.
- **Ainda conferir:** concluir corrida em primeiro e em outra posição; confirmar que a fala só sai uma vez, reflete a posição final e não é confundida com fim de sessão/volta.
- **Resultado do teste:** `____________________________________________`.

### 10. Penalidades nativas do Assetto Corsa/CSP

- **Estado:** leitura dos campos nativos e avisos correspondentes permanecem implementados; validação em pista pendente.
- **Inclui:** leitura de `currentPenaltyType`, `currentPenaltyParameter` e da bandeira `ReturnToPits`, avisos de penalidade ativa, lembretes, aviso de cumprimento, estado resumido com parâmetros no painel e botão manual **Ler penalidade do jogo** (somente leitura; não aplica punição).
- **Classificação exibida conforme o SDK do CSP instalado:** tipo 1 = paradas obrigatórias (parâmetro em voltas); tipo 2 = teleporte/espera nos boxes (parâmetro em segundos); tipo 3 = reduzir velocidade por segundos; tipo 4 = bandeira preta; tipo 5 = liberar bandeira preta. A bandeira `ReturnToPits` é mostrada separadamente. O SDK informa que `currentPenaltyType` é preenchido para o carro do jogador.
- **Ainda conferir:** usar uma punição originada pelo próprio jogo/CSP e observar se a Sally identifica o tipo correto, lembra no momento apropriado e limpa o estado depois do cumprimento.
- **Limite técnico:** o aviso só pode ser mais específico quando o jogo expõe o tipo/parâmetro. Se o campo não vier disponível, a Sally pode dar uma chamada genérica ou mostrar “indisponível”.
- **Resultado observado:** `____________________________________________`.

### 11. Biblioteca de áudio e arquivos

- **Estado:** verificada estruturalmente.
- **Evidência:** inventário recente encontrou 25 categorias, 968 pastas de frases e 6.222 arquivos WAV; os cabeçalhos WAV foram validados e as legendas auditadas cobrem os respectivos conjuntos de WAV.
- **Uso das falas:** `AUDIOS-FALTANTES.md` documenta o que está ligado, o que depende de um gatilho ainda não implementado e o que não tem dado disponível no Assetto Corsa.
- **Ainda conferir:** ouvir uma seleção de cada categoria e confirmar a pronúncia, o volume e a intenção da frase no contexto.
- **Nota de distribuição:** o próprio documento de áudio recomenda respeitar os termos do pack fonte antes de redistribuir os WAVs.

### 12. IA e dependências externas

- **Estado:** IA online removida da operação atual; comportamento baseado em regras locais e clipes gravados.
- **Resultado prático:** não é necessário cadastrar chave, testar endpoint de IA ou manter conexão de internet para a seleção local de falas descrita pelo projeto.
- **Ainda conferir:** confirmar que a tela/configuração instalada no jogo corresponde à versão local atual, caso o jogo ainda mostre opções antigas de chave/API.

### 13. Robustez e erros

- **Estado:** correções recentes passaram por verificações estáticas e simulações direcionadas.
- **Evidência:** 12/12 arquivos Lua passaram na análise sintática; 11 `require`s, 10 ações usadas pela UI e as chaves de idioma foram cruzados sem faltas. Simulações confirmaram leitura manual e avisos para parada obrigatória, retorno/espera nos boxes, redução de velocidade, bandeira preta, bandeira `ReturnToPits` e liberação da penalidade.
- **Limite:** simulação de lógica não substitui o runtime do Assetto Corsa/CSP. A saída limpa da sessão recente e a ausência de erros específicos da Sally são bons sinais, não uma prova de ausência de todo bug.
- **Ainda conferir:** iniciar e encerrar sessões, reiniciar app e alternar treino/corrida sem erros ou estado antigo persistente.

## Evidência da sessão mais recente

- **Sessão observada:** 05/10/2026; log principal encerrou com saída limpa e gravação do replay da sessão.
- **Sally:** o log do CSP registrou eventos de criação de áudio em categorias de telemetria e rádio, incluindo pneus, estratégia, combustível, condições, tempos e paradas obrigatórias.
- **Erros:** não foram encontradas mensagens de erro/falha/exceção específicas da Sally no trecho de log analisado.
- **Penalidades:** não houve evento nativo de penalidade nessa atividade que confirme o comportamento de detecção e cumprimento.
- **Eventos ausentes nessa sessão:** sem evidência nova de colisão grave, resultado final da corrida ou fala correspondente a vitória/derrota.
- **Conclusão:** a sessão apoia que chamadas normais estão acionando; os casos especiais listados acima continuam como testes pendentes.

## Checklist de teste para fechar o projeto

Preencha durante ou logo após cada sessão:

| Campo | Preencher |
|---|---|
| Data e hora | `____________________________________________` |
| Tipo de sessão (treino/qualificação/corrida) | `____________________________________________` |
| Pista e carro | `____________________________________________` |
| Versão do app/CSP | `____________________________________________` |
| Idioma e volumes usados | `____________________________________________` |
| Punição nativa do jogo testada? | `Sim / Não / Não se aplica` |
| Replay ou arquivos de log guardados? | `____________________________________________` |

### Resultado por cenário

| Cenário | Esperado | Observado / anotações | Fechado? |
|---|---|---|---|
| App abre e painel aparece | Sem erro e elementos legíveis | `________________________` | [ ] |
| Sally sem fundo distrativo | Recorte transparente e fora do foco da pista | `________________________` | [ ] |
| Mudança de expressão | Expressão corresponde à fala e retorna ao normal | `________________________` | [ ] |
| Passagem pela esquerda | Aviso de lado correto e no momento certo | `________________________` | [ ] |
| Passagem pela direita / três lado a lado | Aviso de lado correto e sem duplicar | `________________________` | [ ] |
| Toque, zebra ou saída leve | Não perguntar se o piloto está bem | `________________________` | [ ] |
| Colisão forte / dano crítico | Pergunta apropriada, uma vez | `________________________` | [ ] |
| Combustível e pneus | Avisos coerentes com telemetria | `________________________` | [ ] |
| Vitória / posição final | Reação correta e sem duplicidade | `________________________` | [ ] |
| Penalidade nativa atribuída | Sally reconhece o tipo reportado pelo jogo | `________________________` | [ ] |
| Penalidade nativa cumprida | Sally anuncia/mostra a liberação e limpa o estado | `________________________` | [ ] |
| Reinício de sessão | Sem aviso, punição ou estado antigo fantasma | `________________________` | [ ] |

## Alterações locais e publicação

No momento deste formulário há alterações locais ainda não commitadas em `AC-Engineer-Sally.lua`, `AUDIOS-FALTANTES.md`, `lang.lua`, `rep.lua`, `sally.lua`, `tele.lua`, `ui.lua`, `warn.lua`, neste formulário de status e nas legendas de `finished_race`/`finished_race_last`. Isso descreve o estado do checkout local; não confirma que todas essas alterações já estejam no GitHub.

| Próxima etapa de entrega | Estado |
|---|---|
| Revisar o diff local final | [ ] |
| Testar os cenários pendentes em jogo | [ ] |
| Atualizar versão/notas, se for preparar uma nova versão | [ ] |
| Fazer commit/publicar alterações revisadas | [ ] |

## Próxima sequência recomendada

1. **Teste curto de interface:** abrir Ajustes, alternar idioma, usar prévias e conferir avatar/transparência durante a pilotagem.
2. **Teste curto de spotter e colisão:** validar os lados do spotter e confirmar a diferença entre toque leve e colisão forte.
3. **Corrida completa:** concluir e conferir a reação de posição final, os áudios e as legendas.
4. **Teste de penalidade nativa:** usar uma punição fornecida pelo jogo/CSP, observar o painel e os avisos e guardar o replay/log da sessão.
5. **Revisão final:** olhar os resultados e logs; corrigir somente o que falhar; depois revisar/publicar as alterações locais.

**Status para atualizar depois dos testes:** `PENDENTE`
**Data da próxima revisão:** `____________________`
**Observações:** `______________________________________________________________________`

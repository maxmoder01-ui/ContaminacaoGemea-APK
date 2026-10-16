# Estrutura do projeto
- `assets/characters/torajo_base.glb`: modelo base enviado pelo usuário e integrado ao jogador.
- `assets/characters/`: documentação de estado dos personagens.
- `assets/audio/`: sons WAV sintetizados para a primeira fase.
- `assets/animations/`: reservado para clips/recursos de animação esquelética.
- `assets/maps/`: reservado para mapas externos; a arena atual é criada por `scripts/game.gd`.
- `assets/powers/`: reservado para poderes; o pulso atual está implementado em `scripts/game.gd`.
- `scripts/game.gd`: fase, HUD, coleta, saída, áudio e estados de vitória/derrota.
- `scripts/player.gd`: movimento e integração do modelo GLB de Torajo.
- `scripts/voluntaria.gd`: perseguição e atordoamento da inimiga provisória.

## Etapa 3 — sistemas de perseguição e energia
- `scripts/player.gd`: energia de corrida de 0 a 100; consumo durante corrida em movimento e recuperação quando não corre.
- `scripts/voluntaria.gd`: velocidade de perseguição aumenta conforme registros recuperados.
- `scripts/game.gd`: barra de energia e indicador de ameaça na HUD.

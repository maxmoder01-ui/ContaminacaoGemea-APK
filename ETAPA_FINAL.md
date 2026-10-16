# Etapa final de aprimoramento (protótipo de habilidades)

Esta etapa adiciona botões de teste para habilidades já definidas no conceito:

- **Torajo — Maçã:** cria uma isca temporária para desviar a Voluntária.
- **Pessy — Clone:** cria uma isca temporária para testar distração/mecanismos.
- **Jay — Super audição:** informa a distância aproximada da Voluntária e marca sua posição por um instante.
- **Zulmi — Foco/contensão:** atordoa brevemente a Voluntária se estiver próxima; fora do alcance, exibe feedback de investigação.
- **Linn — Regeneração:** recupera parte da energia de corrida como protótipo de mecânica de suporte.
- **Morajo:** permanece como evento narrativo contaminado/jumpscare e fuga futura; não foi atribuído um poder que ainda não foi definido.

**Limitação:** estes são protótipos funcionais das ideias, não personagens selecionáveis completos nem habilidades finais. O clone e a maçã são representados por marcadores temporários; ainda faltam modelos/rigs próprios, animações finais e validação dentro do Godot.

## Exportar APK pelo GitHub Actions

O projeto inclui `export_presets.cfg` e `.github/workflows/export-android.yml`.

1. Envie o conteúdo deste projeto para um repositório GitHub. Se usar um repositório já existente, mantenha a pasta `ContaminacaoGemea_3D_Completo/` e a pasta `.github/workflows/` na raiz do repositório (a workflow procura o projeto dentro dessa pasta).
2. Abra o repositório no GitHub e vá a **Actions**.
3. Se aparecer o aviso, habilite workflows para o repositório.
4. Escolha **Exportar APK Android** → **Run workflow**.
5. Aguarde a conclusão. Abra a execução concluída e, na seção **Artifacts**, baixe `ContaminacaoGemea-Android-APK`.
6. Extraia o ZIP do artifact no celular e instale o APK. O Android pode pedir autorização para instalar apps dessa origem.

A workflow só confirma que a exportação conseguiu produzir o APK; isso não substitui teste no aparelho. Se falhar, abra a execução, copie o primeiro erro completo e corrija-o antes de tentar de novo.

## Se o projeto já estiver na raiz do repositório

Se `project.godot` estiver diretamente na raiz, edite os dois comandos da workflow e substitua `--path ContaminacaoGemea_3D_Completo` por `--path .`; ajuste o `path` do artifact para `build/ContaminacaoGemea.apk` (o caminho de saída do comando permanece relativo ao diretório de trabalho do runner).

## Observação de segurança/publicação

O preset é para APK de teste assinado com a configuração padrão do Godot/ambiente CI. Para publicar comercialmente, configure uma chave de assinatura própria protegida como GitHub Secrets e revise identificador de pacote, versão, permissões e requisitos atuais da loja.

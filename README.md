# Suporte Remoto (HopToDesk)

Instalação e configuração automatizada de suporte remoto para clientes e parceiros via HopToDesk, com sincronização automática de ID, configuração de senha permanente e notificação em tempo real via Webhook (Make.com).

---

## ⚡ Método 1: Instalação Direta via Web (Recomendado - 1 Linha)

Para instalar em qualquer computador Windows sem precisar baixar arquivos e 100% livre de bloqueios do Windows 11 Smart App Control:

Abra o **PowerShell como Administrador** e execute:
```powershell
irm https://raw.githubusercontent.com/leonvrdx/Suporte-Remoto/main/instalar.ps1 | iex
```

---

## 📦 Método 2: Instalação via Pacote ZIP (Dois Cliques)

Para enviar o instalador pronto para o cliente ou operador de suporte:
1. Baixe ou envie o arquivo **`Suporte-Remoto.zip`** (apenas ~6 KB).
2. Extraia os arquivos.
3. Dê dois cliques em **`Instalador Suporte Remoto.cmd`**.

---

## 🛠️ Recursos Integrados

* **Padrão HopToDesk Direto**: Sem telas de escolha ou dependências problemáticas de releases de terceiros.
* **Zero Erro 404**: Download direto oficial dos servidores CDN do HopToDesk com fallbacks automáticos em cascata.
* **Compatibilidade 32 e 64 bits**: Detecção dinâmica de instalação e suporte a arquiteturas Windows.
* **Segurança e Senhas Fortes**: Senha permanente alfanumérica inequívoca (sem caracteres que causam conflito em linha de comando) e ativação de acesso não supervisionado.
* **Feedback em Tempo Real**: Progresso narrado passo a passo `[1/5]..[5/5]` na tela do terminal e barra visual de download.
* **Integração Make.com**: Notificação assíncrona automática com envio dos dados (`ferramenta`, `aplicativo`, `app`, `parceiro`, `computador`, `id`, `senha`, `textoCompleto`).
* **Relatório Automático**: Salvamento imediato dos dados na Área de Trabalho (`HopToDesk Dados - <Loja>.txt`), cópia para Área de Transferência e abertura no Bloco de Notas.

---

## 📁 Estrutura dos Arquivos

* **`instalar.ps1`**: Script web para execução em linha única (`irm ... | iex`).
* **`config.ps1`**: Script principal de instalação local.
* **`Instalador Suporte Remoto.cmd`**: Disparador local por lote (dois cliques com auto-elevação UAC).
* **`Suporte-Remoto.zip`**: Pacote compactado oficial para distribuição rápida.

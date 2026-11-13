# Suporte Remoto (RustDesk & HopToDesk)

Instalação e configuração automatizada de suporte remoto para clientes e parceiros (HopToDesk e RustDesk), com sincronização de ID, senha permanente e notificação em tempo real via Webhook (Make.com).

---

## ⚡ Método 1: Instalação Direta via Web (Recomendado - 1 Linha)

Para instalar em qualquer computador Windows sem precisar baixar arquivos e livre de bloqueios do Windows 11:

Abra o **PowerShell como Administrador** e execute:
```powershell
irm https://raw.githubusercontent.com/leonvrdx/Suporte-Remoto/main/instalar.ps1 | iex
```

---

## 📦 Método 2: Instalação via Pacote ZIP (Dois Cliques)

Para enviar o instalador pronto para o cliente:
1. Baixe ou envie o arquivo **`Suporte-Remoto.zip`** (apenas ~7 KB).
2. Extraia os arquivos.
3. Dê dois cliques em **`Instalador Suporte Remoto.cmd`**.

---

## 🛠️ Recursos Integrados

* **Zero Erro 404**: Download direto oficial com fallbacks automáticos em cascata.
* **Compatibilidade 32 e 64 bits**: Detecção dinâmica de instalação em `Program Files` e `Program Files (x86)`.
* **Segurança e Senhas Fortes**: Senha permanente alfanumérica inequívoca (sem caracteres que quebram terminais ou teclados) e ativação de acesso não supervisionado.
* **Feedback em Tempo Real**: Progresso narrado passo a passo na tela do terminal.
* **Integração Make.com**: Notificação assíncrona automática com envio dinâmico do nome do aplicativo (`ferramenta`, `aplicativo` e `app`).

---

## 📁 Estrutura dos Arquivos

* **`instalar.ps1`**: Script web para execução em linha única (`irm ... | iex`).
* **`config.ps1`**: Script principal de instalação local.
* **`Instalador Suporte Remoto.cmd`**: Disparador local por lote (dois cliques).
* **`Suporte-Remoto.zip`**: Pacote compactado oficial para distribuição rápida.

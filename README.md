# Suporte Remoto (RustDesk & HopToDesk)

Instalação e configuração automatizada de suporte remoto para clientes e parceiros (HopToDesk e RustDesk), com sincronização de ID, senha permanente e notificação em tempo real via Webhook (Make.com).

---

## ⚡ Instalação Rápida via Web (Sem Bloqueio de Segurança)

Para instalar em qualquer computador Windows sem baixar arquivos na Área de Trabalho e sem ser barrado pelo Smart App Control do Windows 11:

Abra o **PowerShell como Administrador** e cole o comando:
```powershell
irm https://raw.githubusercontent.com/leonvrdx/Suporte-Remoto/main/instalar.ps1 | iex
```

---

## 💻 Instalação Local (Dois Cliques)

Basta enviar a pasta ou o atalho para o cliente:
- Execute **`Instalador Suporte Remoto.cmd`**

O script:
1. Solicita privilégios de Administrador.
2. Abre a interface para escolher entre **RustDesk** ou **HopToDesk**.
3. Coleta o nome do parceiro e identifica a máquina.
4. Baixa o instalador oficial diretamente das CDNs oficiais (com fallbacks resilientes).
5. Instala silenciosamente, inicia o serviço e recupera o ID.
6. Gera uma senha forte alfanumérica permanente e configura as permissões de acesso.
7. Dispara os dados via JSON para o Webhook do Make.com.
8. Salva o `.txt` na Área de Trabalho, copia os dados para a Área de Transferência e abre no Bloco de Notas.

---

## 📁 Estrutura do Repositório

- **`instalar.ps1`**: Script web para execução em linha única (`irm ... | iex`).
- **`config.ps1`**: Script principal de instalação e integração.
- **`Instalador Suporte Remoto.cmd`**: Disparador local rápido para clientes.
- **`src/Program.cs`** e **`src/app.manifest`**: Código-fonte do executável C# nativo.
- **`build.cmd`** e **`build.ps1`**: Scripts para compilação local via `csc.exe`.

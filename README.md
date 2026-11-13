# Instalador Suporte Remoto (RustDesk & HopToDesk)

Solução automatizada e autônoma para distribuição de suporte remoto a clientes e parceiros com configuração automática de ID, senha permanente e integração com Webhook (Make.com).

## 🚀 Como Usar no Cliente

Basta enviar o arquivo único:
- **`Instalador Suporte Remoto.exe`** (~34.7 MB)

O cliente simplesmente dá dois cliques no arquivo:
1. O Windows solicita permissão de Administrador (UAC nativo).
2. O cliente escolhe a ferramenta (**RustDesk** recomendado ou **HopToDesk** alternativo).
3. Informa o nome do parceiro/cliente e o identificador do computador.
4. Por padrão, a instalação é **100% offline** (utiliza os instaladores embutidos no `.exe`, sem depender de internet para baixar o pacote inicial e sem chance de erro 404). Caso desejado, há a opção de marcar para buscar a versão mais recente na web.
5. Em poucos segundos, o aplicativo é instalado silenciosamente, o serviço do Windows é iniciado, o ID de acesso é sincronizado, a senha permanente é gerada e aplicada, e os dados são:
   - Salvos em um arquivo `.txt` na Área de Trabalho do cliente.
   - Copiados para a Área de Transferência.
   - Abertos no Bloco de Notas.
   - Enviados automaticamente para o Webhook do Make.com configurado (com o nome dinâmico da ferramenta).

---

## 🛠️ Estrutura do Projeto

- **`Instalador Suporte Remoto.exe`**: Executável final pronto para envio ao cliente.
- **`build.cmd`**: Atalho em lote para recompilar o `.exe` com um clique duplo.
- **`build.ps1`**: Script que invoca o compilador nativo do Windows (`csc.exe`).
- **`src\Program.cs`**: Código-fonte C# da interface Windows Forms e automação do suporte.
- **`src\app.manifest`**: Manifesto de elevação nativa com UAC (`requireAdministrator`).
- **`build\resources\`**: Contém os instaladores oficiais de base compactados dentro do executável (`RustDesk.exe` e `HopToDesk.exe`).

---

## 🔄 Como Atualizar os Instaladores Embutidos no Futuro

Se desejar atualizar as versões dos instaladores que vêm dentro do `.exe`:
1. Substitua os arquivos dentro da pasta `build\resources\`:
   - `build\resources\RustDesk.exe`
   - `build\resources\HopToDesk.exe`
2. Dê dois cliques no arquivo **`build.cmd`** (ou execute `.\build.ps1` no PowerShell).
3. O novo `Instalador Suporte Remoto.exe` será gerado automaticamente.

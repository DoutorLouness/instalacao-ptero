<p align="center">
  <img src="https://gustavozs.ovh/assets/Astralvioleta.png" alt="Astral Cloud Logo" width="200">
</p>

<h1 align="center">🌌 Astral Cloud - Instalador automático (Pterodactyl + Wings)</h1>

<p align="center">
  <img src="https://img.shields.io/badge/Version-2.1.0-6e54ff?style=for-the-badge" alt="Version">
  <img src="https://img.shields.io/badge/Status-Stable-2ea44f?style=for-the-badge" alt="Status">
  <img src="https://img.shields.io/badge/License-MIT-E9430F?style=for-the-badge" alt="License">
</p>

<p align="center">
  <strong>A forma definitiva e à prova de falhas para instalar sua infraestrutura de hospedagem.</strong><br>
  Script One-Click oficial da Astral Cloud, otimizado para servidores KVM e focado no público brasileiro.
</p>

---

## 💻 Sistemas Operacionais Suportados

Nosso instalador foi construído do zero para rodar perfeitamente nas distribuições Linux mais utilizadas em hosting. Testado e homologado para:

| Distribuição | Versões Suportadas | Status | Observações |
| :--- | :---: | :---: | :--- |
| **Ubuntu** | `22.04 LTS` até `24.04 LTS` | 🟢 Excelente | Otimização de Mirrors BR automática. |
| **Debian** | `11`, `12` e `13` | 🟢 Excelente | Repositórios otimizados e suporte nativo. |

> [!WARNING]
> **Atenção à Virtualização:** O Pterodactyl Wings utiliza **Docker**. Por isso, seu servidor VPS **DEVE** usar virtualização **KVM** ou ser um servidor Dedicado. Virtualizações antigas como OpenVZ ou LXC não são suportadas.

---

## ⚡ Instalação Rápida (One-Click)

Acesse seu servidor via SSH com o usuário `root`. Copie o comando abaixo e cole no terminal:

> [!IMPORTANT]
> **Certificados SSL (HTTPS):** Para instalar com SSL (Recomendado), seus domínios (Painel e Node) **já devem estar apontados (DNS Tipo A)** para o IP do seu servidor antes de executar o script.

### 🟠 Para Ubuntu (22.04 até 24.04) & 🔴 Debian (11 até 13)
Este comando instala as dependências necessárias e executa o instalador da **Astral Cloud**:

```bash
curl -sSL "https://raw.githubusercontent.com/DoutorLouness/astral-install/refs/heads/main/install.sh?v=$RANDOM" | sudo bash

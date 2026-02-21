<p align="center">
  <img src="https://gustavozs.ovh/assets/Astralvioleta.png" alt="Astral Cloud Logo" width="200">
</p>

<h1 align="center">🌌 Astral Cloud - Auto Installer (Pterodactyl + Wings)</h1>

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

Nosso instalador foi reescrito do zero para detectar e adaptar-se a diversas distribuições Linux. Testado e homologado para os seguintes sistemas:

| Distribuição | Versões Suportadas | Status | Observações |
| :--- | :---: | :---: | :--- |
| **Ubuntu** | `22.04 LTS` até `24.04 LTS` | 🟢 Excelente | Otimização de Mirrors BR aplicada automaticamente. |
| **Debian** | `11 (Bullseye)`, `12 (Bookworm)` | 🟢 Excelente | Repositórios otimizados para `ftp.br.debian.org`. |
| **Rocky Linux** | `8.x`, `9.x` | 🔵 Estável | Repositórios EPEL e Remi configurados nativamente. |
| **AlmaLinux** | `8.x`, `9.x` | 🔵 Estável | Repositórios EPEL e Remi configurados nativamente. |
| **RHEL** | `8.x`, `9.x` | 🔵 Estável | Compatibilidade total com a base RedHat. |

> [!WARNING]
> **Atenção à Virtualização:** O Pterodactyl Wings utiliza **Docker**. Por isso, seu servidor VPS **deve** usar virtualização **KVM** ou ser um servidor Dedicado. Virtualizações antigas como OpenVZ ou LXC não são suportadas.

---

## ⚡ Instalação Rápida (One-Click)

Acesse seu servidor via SSH com o usuário `root`. **Escolha o comando correspondente ao seu Sistema Operacional** e cole no terminal:

> [!IMPORTANT]
> **Certificados SSL (HTTPS):** Se você for instalar com SSL (Recomendado), os domínios do Painel e do Node **já devem estar apontados (DNS Tipo A)** para o IP do seu servidor antes de executar o script.

### 🟠 Para Ubuntu (22.04 até 24.04)
O Ubuntu geralmente já possui as ferramentas básicas necessárias. Basta rodar o comando abaixo:
```bash
curl -sSL [https://raw.githubusercontent.com/DoutorLouness/astral-install/main/install.sh](https://raw.githubusercontent.com/DoutorLouness/astral-install/main/install.sh) | sudo bash

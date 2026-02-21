<p align="center">
  <img src="https://gustavozs.ovh/assets/Astralvioleta.png" width="180" alt="Astral Cloud Logo">
</p>

<h1 align="center">🌌 Astral Cloud — Auto Installer</h1>

<p align="center">
  <img src="https://img.shields.io/badge/Version-2.1.0-6e54ff?style=for-the-badge">
  <img src="https://img.shields.io/badge/Status-Stable-2ea44f?style=for-the-badge">
  <img src="https://img.shields.io/badge/OS-Ubuntu%20%7C%20Debian-1f6feb?style=for-the-badge">
  <img src="https://img.shields.io/badge/License-MIT-E9430F?style=for-the-badge">
</p>

<p align="center">
  <strong>Instale sua infraestrutura de hospedagem em minutos.</strong><br>
  Script One-Click para <b>Pterodactyl Panel + Wings</b> com Docker, SSL e mirrors brasileiros.
</p>

---

## 🚀 O que este script faz?

O **Astral Cloud Installer** elimina a necessidade de seguir tutoriais complexos. Com um único comando, ele prepara todo o ambiente:

* **Dependências:** Instala PHP, MySQL, Nginx e Docker.
* **Segurança:** Configura Firewall (UFW) e isolamento de containers.
* **Produção:** Otimiza mirrors (BR) para downloads ultra-rápidos.
* **SSL:** Emite certificados Let's Encrypt automaticamente.
* **Automação:** Configura inicialização automática (Systemd) para o Painel e Wings.

---

## 💻 Compatibilidade

Focado nas distribuições Linux mais estáveis para servidores KVM:

| Sistema | Versões Suportadas | Status |
| :--- | :--- | :--- |
| **Ubuntu** | `22.04 LTS` e `24.04 LTS` | 🟢 Recomendado |
| **Debian** | `11`, `12` e `13 (Trixie)` | 🟢 Estável |

> [!CAUTION]
> **Virtualização:** O Wings exige suporte a Docker. Use **KVM** ou **Dedicado**. O script **não funciona** em OpenVZ ou LXC.

---

## ⚡ Instalação Rápida (One-Click)

Acesse seu terminal como **root** e execute o comando abaixo:

```bash
curl -sSL "[https://raw.githubusercontent.com/DoutorLouness/astral-install/main/install.sh](https://raw.githubusercontent.com/DoutorLouness/astral-install/main/install.sh)" | sudo bash

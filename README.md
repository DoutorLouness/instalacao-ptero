<p align="center">
  <img src="https://gustavozs.ovh/assets/Astralvioleta.png" width="180" alt="Astral Cloud Logo">
</p>

<h1 align="center">🌌 Astral Cloud — Instalador automático (Painel + Wings)</h1>

<p align="center">
  <img src="https://img.shields.io/badge/Version-2.1.0-6e54ff?style=for-the-badge">
  <img src="https://img.shields.io/badge/Status-Stable-2ea44f?style=for-the-badge">
  <img src="https://img.shields.io/badge/Linux-Ubuntu%20%7C%20Debian-1f6feb?style=for-the-badge">
  <img src="https://img.shields.io/badge/License-MIT-E9430F?style=for-the-badge">
</p>

<p align="center">
  Instale sua infraestrutura de hospedagem em minutos.<br>
  Script automático para configurar <b>Pterodactyl Panel + Wings</b> com Docker, SSL e otimizações prontas para produção.
</p>

---

## 🚀 Sobre

O **Astral Cloud Installer** foi criado para simplificar a instalação do **:contentReference[oaicite:0]{index=0}** e do **:contentReference[oaicite:1]{index=1}**.

Nada de tutoriais enormes ou configs manuais.

Você executa **um comando** e o servidor sai funcionando.

Ideal para:

- Hospedagem de Minecraft
- FiveM
- Bots Discord
- VPS gamers
- Infraestrutura própria

---

## ⚙️ O que o script faz automaticamente

✔ Instala todas as dependências  
✔ Configura Docker  
✔ Instala Painel  
✔ Instala Wings  
✔ Configura banco de dados  
✔ Ajusta firewall  
✔ Ativa serviços no boot  
✔ Emite SSL (Let's Encrypt)  
✔ Otimiza mirrors brasileiros  
✔ Ambiente pronto para produção  

---

## 💻 Sistemas suportados

| Sistema | Versões | Status |
|--------|----------|-----------|
| **:contentReference[oaicite:2]{index=2}** | 22.04 → 24.04 LTS | 🟢 Recomendado |
| **:contentReference[oaicite:3]{index=3}** | 11, 12, 13 | 🟢 Estável |

---

## ⚠️ Requisitos importantes

Antes de instalar:

### Virtualização
O Wings utiliza **Docker**, então seu servidor precisa ser:

- KVM ✅
- Dedicado ✅
- OpenVZ ❌
- LXC ❌

### Domínio (para SSL)
Se for usar HTTPS:

- Aponte o domínio para o IP do servidor (DNS tipo A)
- Aguarde a propagação

---

## ⚡ Instalação rápida (One-Click)

Conecte via SSH como **root** e execute:

```bash
curl -sSL "https://raw.githubusercontent.com/DoutorLouness/astral-install/refs/heads/main/install.sh?v=$RANDOM" | bash

# 📧 Ultra SIEM SMTP Email Alert Setup Guide

## 🎯 **What You Need for Email Alerts**

Ultra SIEM needs SMTP (Simple Mail Transfer Protocol) to send you email alerts when threats are detected. Here's what you need:

### **Required Information:**

1. **Email Address**: `yassermn238@gmail.com` ✅ (Already configured)
2. **SMTP Server**: `smtp.gmail.com` ✅ (Already configured)
3. **SMTP Port**: `587` ✅ (Already configured)
4. **App Password**: You need to generate this (see steps below)

---

## 🔐 **Step 1: Generate Gmail App Password**

Since you're using Gmail, you need to create an "App Password" (not your regular password):

### **Enable 2-Factor Authentication First:**

1. Go to [Google Account Settings](https://myaccount.google.com/)
2. Click "Security" in the left sidebar
3. Under "Signing in to Google," click "2-Step Verification"
4. Follow the steps to enable it

### **Generate App Password:**

1. Go to [Google Account Settings](https://myaccount.google.com/)
2. Click "Security" in the left sidebar
3. Under "Signing in to Google," click "App passwords"
4. Select "Mail" and "Other (Custom name)"
5. Name it "Ultra SIEM"
6. Click "Generate"
7. **Copy the 16-character password** (it looks like: `abcd efgh ijkl mnop`)

---

## ⚙️ **Step 2: Configure Ultra SIEM**

### **Option A: Environment Variable (Recommended)**

Create a `.env` file in your SIEM directory:

```powershell
# Create .env file
New-Item -Path ".env" -ItemType File -Force

# Add your app password
Add-Content -Path ".env" -Value "GMAIL_APP_PASSWORD=your_16_character_app_password_here"
```

**Replace `your_16_character_app_password_here` with the actual password from Step 1.**

### **Option B: Direct Configuration**

If you prefer to set it directly, edit the docker-compose file:

```yaml
environment:
  - GMAIL_APP_PASSWORD=your_16_character_app_password_here
```

---

## 🚀 **Step 3: Test Email Alerts**

### **Start Ultra SIEM:**

```powershell
# Stop existing containers
docker-compose -f docker-compose.simple.yml down

# Start with new configuration
docker-compose -f docker-compose.simple.yml up -d

# Wait for services to start
Start-Sleep -Seconds 30
```

### **Test Email Configuration:**

```powershell
# Check Grafana logs for SMTP errors
docker-compose -f docker-compose.simple.yml logs grafana
```

### **Trigger a Test Alert:**

1. Go to Grafana: http://localhost:3000 (admin/admin)
2. Go to Alerting → Contact points
3. Click "Admin Email"
4. Click "Test" button
5. Check your email for the test message

---

## 🔧 **Alternative Email Providers**

If you prefer a different email provider, here are the settings:

### **Outlook/Hotmail:**

```yaml
smtphost: "smtp-mail.outlook.com:587"
smtpuser: "your_email@outlook.com"
```

### **Yahoo:**

```yaml
smtphost: "smtp.mail.yahoo.com:587"
smtpuser: "your_email@yahoo.com"
```

### **Custom SMTP Server:**

```yaml
smtphost: "your_smtp_server.com:587"
smtpuser: "your_username"
```

---

## 🚨 **Security Best Practices**

1. **Never commit passwords to Git**

   - Use `.env` files (already in `.gitignore`)
   - Use environment variables

2. **Use App Passwords**

   - Don't use your main email password
   - Generate app-specific passwords

3. **Regular Password Rotation**
   - Change app passwords every 90 days
   - Monitor for suspicious activity

---

## 🔍 **Troubleshooting**

### **Common Issues:**

**"Authentication failed"**

- Check if 2FA is enabled
- Verify app password is correct
- Ensure no spaces in the password

**"Connection timeout"**

- Check firewall settings
- Verify SMTP server and port
- Try different ports (465 for SSL)

**"No emails received"**

- Check spam folder
- Verify email address is correct
- Check Grafana logs for errors

### **Debug Commands:**

```powershell
# Check Grafana configuration
docker exec -it siem-grafana-1 cat /etc/grafana/grafana.ini | grep smtp

# Test SMTP connection
docker exec -it siem-grafana-1 curl -v telnet://smtp.gmail.com:587

# View Grafana logs
docker-compose -f docker-compose.simple.yml logs -f grafana
```

---

## 📧 **Email Alert Examples**

Once configured, you'll receive emails like:

```
Subject: [Ultra SIEM Alert] High Threat Count Detected

🚨 Ultra SIEM Security Alert

Alert: High Threat Count Detected

Details: 15 threats detected in the last 5 minutes, exceeding threshold of 10

Time: 2024-01-15 14:30:25
Severity: High

This is an automated alert from your Ultra SIEM system.
```

---

## ✅ **Verification Checklist**

- [ ] 2-Factor Authentication enabled on Gmail
- [ ] App Password generated and copied
- [ ] `.env` file created with app password
- [ ] Docker containers restarted
- [ ] Test email sent successfully
- [ ] Email received in inbox (not spam)
- [ ] Alert rules configured in Grafana

---

## 🆘 **Need Help?**

If you encounter issues:

1. **Check the logs**: `docker-compose logs grafana`
2. **Verify Gmail settings**: Ensure 2FA and app passwords are set up
3. **Test SMTP manually**: Use a simple SMTP test tool
4. **Check firewall**: Ensure port 587 is not blocked

**Your email alerts will be sent to: `yassermn238@gmail.com`**

---

🎉 **Once configured, you'll receive real-time security alerts whenever Ultra SIEM detects threats!**

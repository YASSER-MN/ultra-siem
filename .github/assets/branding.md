# 🎨 Ultra SIEM Branding Guidelines

## 🏆 **Brand Identity**

Ultra SIEM represents the future of enterprise security - powerful, accessible, and community-driven.

### **Brand Values**

- **Innovation**: Cutting-edge technology and performance
- **Accessibility**: Security for everyone, not just enterprises
- **Community**: Open source collaboration and knowledge sharing
- **Excellence**: Enterprise-grade quality and reliability
- **Transparency**: Open development and honest communication

---

## 🎨 **Color Palette**

### **Primary Colors**

| Color             | Hex       | RGB           | Usage                               |
| ----------------- | --------- | ------------- | ----------------------------------- |
| **Ultra Green**   | `#00ff00` | `0, 255, 0`   | Primary brand color, success states |
| **Security Blue** | `#0066cc` | `0, 102, 204` | Trust, reliability, enterprise      |
| **Dark Shield**   | `#004000` | `0, 64, 0`    | Text, backgrounds, contrast         |

### **Secondary Colors**

| Color                  | Hex       | RGB            | Usage                        |
| ---------------------- | --------- | -------------- | ---------------------------- |
| **Performance Orange** | `#ff6b35` | `255, 107, 53` | Rust components, performance |
| **Go Blue**            | `#00ADD8` | `0, 173, 216`  | Go services, data processing |
| **Zig Gold**           | `#F7A41D` | `247, 164, 29` | Zig components, analytics    |
| **ClickHouse Yellow**  | `#FFCC01` | `255, 204, 1`  | Database, storage            |

### **Neutral Colors**

| Color           | Hex       | RGB             | Usage                     |
| --------------- | --------- | --------------- | ------------------------- |
| **Pure White**  | `#ffffff` | `255, 255, 255` | Backgrounds, text on dark |
| **Light Gray**  | `#f5f5f5` | `245, 245, 245` | Secondary backgrounds     |
| **Medium Gray** | `#666666` | `102, 102, 102` | Secondary text            |
| **Dark Gray**   | `#333333` | `51, 51, 51`    | Primary text              |

---

## 🔤 **Typography**

### **Primary Font Stack**

```css
font-family: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
```

### **Headings**

- **H1**: `font-size: 2.5rem; font-weight: 700;`
- **H2**: `font-size: 2rem; font-weight: 600;`
- **H3**: `font-size: 1.5rem; font-weight: 600;`
- **H4**: `font-size: 1.25rem; font-weight: 500;`

### **Body Text**

- **Regular**: `font-size: 1rem; font-weight: 400; line-height: 1.6;`
- **Small**: `font-size: 0.875rem; font-weight: 400; line-height: 1.5;`
- **Code**: `font-family: 'JetBrains Mono', 'Fira Code', monospace;`

---

## 🛡️ **Logo Usage**

### **Primary Logo**

- **Format**: SVG (preferred), PNG, JPG
- **Minimum Size**: 32px height
- **Clear Space**: Equal to the height of the "U" in "ULTRA"
- **Background**: Works on light and dark backgrounds

### **Logo Variations**

#### **Full Logo**

- Includes "ULTRA SIEM" text
- Use for headers, documentation, presentations

#### **Icon Only**

- Shield symbol without text
- Use for favicons, small spaces, social media

#### **Monochrome**

- Single color version
- Use for printing, embroidery, limited color applications

### **Logo Don'ts**

- ❌ Don't stretch or distort
- ❌ Don't change colors
- ❌ Don't add effects or shadows
- ❌ Don't place on busy backgrounds
- ❌ Don't make smaller than minimum size

---

## 📐 **Layout & Spacing**

### **Grid System**

- **Base Unit**: 8px
- **Container Width**: 1200px max
- **Gutters**: 24px (3 × base unit)
- **Margins**: 16px, 24px, 32px, 48px

### **Spacing Scale**

```css
--space-xs: 4px; /* 0.5 × base */
--space-sm: 8px; /* 1 × base */
--space-md: 16px; /* 2 × base */
--space-lg: 24px; /* 3 × base */
--space-xl: 32px; /* 4 × base */
--space-2xl: 48px; /* 6 × base */
--space-3xl: 64px; /* 8 × base */
```

---

## 🎯 **Component Design**

### **Buttons**

#### **Primary Button**

```css
background: #00ff00;
color: #004000;
border: none;
border-radius: 8px;
padding: 12px 24px;
font-weight: 600;
```

#### **Secondary Button**

```css
background: transparent;
color: #00ff00;
border: 2px solid #00ff00;
border-radius: 8px;
padding: 10px 22px;
font-weight: 600;
```

### **Cards**

```css
background: #ffffff;
border: 1px solid #f5f5f5;
border-radius: 12px;
padding: 24px;
box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
```

### **Alerts**

#### **Success**

```css
background: #e6ffe6;
border: 1px solid #00ff00;
color: #004000;
```

#### **Warning**

```css
background: #fff3cd;
border: 1px solid #ffc107;
color: #856404;
```

#### **Error**

```css
background: #ffe6e6;
border: 1px solid #dc3545;
color: #721c24;
```

---

## 📱 **Digital Applications**

### **Website**

- **Header**: Ultra Green background with white text
- **Navigation**: Dark background with green accents
- **Content**: Clean white background with dark text
- **Footer**: Dark background with green highlights

### **Documentation**

- **Code Blocks**: Dark theme with syntax highlighting
- **Sidebar**: Light gray background
- **Content**: White background with dark text
- **Links**: Ultra Green with hover effects

### **Social Media**

- **Profile Picture**: Icon-only logo on Ultra Green background
- **Cover Image**: Full logo with tagline
- **Posts**: Consistent color usage and typography

---

## 🎨 **Iconography**

### **Icon Style**

- **Style**: Outlined with rounded corners
- **Weight**: 2px stroke
- **Size**: 24px × 24px base size
- **Color**: Inherit from parent or use brand colors

### **Common Icons**

- **Security**: Shield with lock
- **Performance**: Lightning bolt
- **Community**: People/group
- **Innovation**: Lightbulb or rocket
- **Support**: Headset or chat bubble

---

## 📊 **Data Visualization**

### **Charts & Graphs**

- **Primary**: Ultra Green (#00ff00)
- **Secondary**: Security Blue (#0066cc)
- **Accent**: Performance Orange (#ff6b35)
- **Background**: Light gray (#f5f5f5)
- **Grid**: Medium gray (#666666)

### **Performance Metrics**

- **Good**: Ultra Green
- **Warning**: Performance Orange
- **Critical**: Red (#dc3545)
- **Neutral**: Medium Gray

---

## 🎬 **Animation Guidelines**

### **Micro-interactions**

- **Duration**: 200-300ms
- **Easing**: Ease-out for natural feel
- **Scale**: Subtle (1.0 to 1.05)

### **Loading States**

- **Spinner**: Ultra Green with fade
- **Skeleton**: Light gray with shimmer
- **Progress**: Green bar with smooth animation

---

## 📋 **Brand Voice**

### **Tone**

- **Professional** but approachable
- **Technical** but understandable
- **Confident** but humble
- **Innovative** but practical

### **Messaging**

- Focus on **benefits** over features
- Emphasize **accessibility** and **democratization**
- Highlight **community** and **collaboration**
- Use **performance** and **efficiency** language

### **Key Phrases**

- "Democratizing enterprise security"
- "1M+ events per second"
- "Zero-cost enterprise solution"
- "Community-driven innovation"
- "Performance without compromise"

---

## 📁 **Asset Organization**

### **File Structure**

```
.github/assets/
├── logos/
│   ├── ultra-siem-logo.svg
│   ├── ultra-siem-icon.svg
│   └── ultra-siem-monochrome.svg
├── icons/
│   ├── security.svg
│   ├── performance.svg
│   └── community.svg
├── templates/
│   ├── presentation.pptx
│   ├── social-media.png
│   └── email-signature.html
└── guidelines/
    ├── branding.md
    ├── color-palette.json
    └── typography.css
```

---

## ✅ **Brand Compliance**

### **Review Checklist**

- [ ] Colors match brand palette
- [ ] Typography follows guidelines
- [ ] Logo usage is correct
- [ ] Spacing is consistent
- [ ] Voice and tone are appropriate
- [ ] Accessibility standards are met

### **Accessibility**

- **Color Contrast**: Minimum 4.5:1 ratio
- **Text Size**: Minimum 16px for body text
- **Focus States**: Clear visual indicators
- **Alt Text**: Descriptive for all images

---

_Ultra SIEM Branding Guidelines v1.0 - Created by Yasser Mounim_

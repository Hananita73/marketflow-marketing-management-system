# MarkFlow — Marketing Management System

A cross-platform marketing management dashboard built with **Flutter** and **Supabase**.

## What is MarkFlow?

MarkFlow is a marketing team's all-in-one tool for managing campaigns, customers, leads, budgets, promotions, and more — accessible from web, desktop, or mobile.

## Screenshots

> Dashboard with KPI cards, charts, and AI assistant panel

## Key Features

- 🔐 **Authentication** — Login, signup, role-based access
- 📊 **Dashboard** — Real-time KPIs and performance charts
- 📢 **Campaigns** — Create, edit, track marketing campaigns
- 👥 **Customers** — Manage customer relationships
- 🎯 **Leads** — Track and score sales leads
- 💰 **Budgets** — Monitor spending vs allocations
- 🎁 **Promotions** — Manage coupons and offers
- 🤖 **AI Assistant** — Ask questions about your marketing data
- 🌙 **Dark Mode** — Full light/dark theme support

## Tech Stack

- **Flutter** — Cross-platform UI
- **Supabase** — Database + Authentication
- **PostgreSQL** — Relational database
- **fl_chart** — Charts and visualizations

## Quick Start

```bash
# Clone the repo
git clone https://github.com/daveontrack/markflow.git

# Install dependencies
flutter pub get

# Run the app
flutter run -d chrome
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── config/                # Supabase credentials
├── core/                  # Theme, routes, constants
├── models/                # Data models + repositories
├── services/              # Auth, API, AI services
├── widgets/               # Reusable UI components
└── screens/               # App pages (one per module)
```

## License

Educational project.

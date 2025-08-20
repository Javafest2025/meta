# ScholarAI Meta Repository

This is the **Meta Repository** for the ScholarAI project, which organizes and orchestrates multiple independent components:

- `Frontend/` — Next.js frontend
- `Microservices/` — Java Spring Boot backend services
- `AI-Agents/` — Python/FastAPI-based AI agents

Each component is maintained in a **separate GitHub repository** and tracked here using **Git submodules**.

---

## 📁 Project Structure

```
Meta/
├── Frontend/                        # → frontend submodule
├── Microservices/
│   └── user-service/               # → user_service submodule
├── AI-Agents/                      # → (add AI agent submodules here)
├── .gitmodules                     # Submodule metadata
└── .github/workflows/             # CI/CD pipelines
```

---

## 🔧 Cloning the Meta Repo

When you first clone this repo, use:

```bash
git clone --recurse-submodules https://github.com/Javafest2025/meta.git
```

Or if you already cloned it without submodules:

```bash
git submodule update --init --recursive
```

---

## 🚀 Adding a New Submodule (Microservice or Agent)

To add a new service or agent to the meta-repo:

```bash
# Format: git submodule add <repo-url> <path-in-meta-repo>
git submodule add https://github.com/Javafest2025/auth-service.git Microservices/auth-service
```

Then commit:

```bash
git add .gitmodules Microservices/auth-service
git commit -m "Added auth-service as submodule"
git push origin main
```

---

## 🔁 Updating Submodules

If a submodule (e.g., `frontend` or `user-service`) has new commits:

```bash
# Step into the submodule
cd Frontend
git pull origin main

# Go back to meta-repo root
cd ..
git add Frontend
git commit -m "Updated frontend submodule to latest commit"
git push
```

---

## 💡 Working with Submodules

### Pull Latest Changes in All Submodules

```bash
git submodule update --remote --merge
```

### Push New Changes from Inside a Submodule

```bash
cd Microservices/user-service
# make changes
git add .
git commit -m "Fix: updated user service logic"
git push origin main
```

Then update the pointer in meta-repo:

```bash
cd ../..
git add Microservices/user-service
git commit -m "Update user-service pointer"
git push
```

---

## ⚙️ CI/CD Strategy

- Each component has its own CI/CD pipeline in its own repo
- The meta-repo has workflows that:
  - Validate `.gitmodules` and folder structure
  - Trigger integration or smoke tests if needed
  - Detect changes in `Frontend/`, `Microservices/**`, or `AI-Agents/**`

---

## 👥 Contributors

This repo is maintained by the ScholarAI team under the `Javafest2025` GitHub organization.

- [Tasriad Ahmed Tias](https://github.com/Tasriad)
- [Farhad Al-Amin Dipto](https://github.com/Legend-2727)

---

## 🛠 Recommended Commands

| Task                            | Command                                                 |
|---------------------------------|----------------------------------------------------------|
| Clone with submodules           | `git clone --recurse-submodules <repo-url>`             |
| Pull all updates                | `git pull && git submodule update --remote --merge`     |
| Add new submodule               | `git submodule add <repo-url> <path>`                   |
| Update a submodule              | `cd path && git pull origin main && cd ..`              |
| Commit updated submodule refs  | `git add path && git commit -m "Update submodule"`      |

---

## 📌 Notes

- Only **submodule pointers** are tracked in this repo — actual code lives in their respective repos.
- This meta-repo is ideal for integration testing, dev onboarding, and central documentation.

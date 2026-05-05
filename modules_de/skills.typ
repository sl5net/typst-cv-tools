// skills.typ
#import "../helpers.typ": *
#import "@preview/brilliant-cv:3.1.2": h-bar, cv-skill-tag

#cv-section("Kenntnisse & Fähigkeiten", tags: ("IT", "job", "Java", "Python", "SQL", "DevOps", "Lehre"))

#cv-skill-with-level(
  type: [Programmierung],
  level: 4,
  info: [Python #h-bar() Java #h-bar() SQL (T-SQL, PL/SQL) #h-bar() PHP #h-bar() JavaScript #h-bar() TypeScript],
  tags: ("Python", "Java", "SQL", "PHP", "JS", "IT","OpenSource")
)

#cv-skill-with-level(
  type: [Frameworks & Tech],
  level: 3,
  info: [Spring #h-bar() Node.js #h-bar() React #h-bar() Angular #h-bar() REST APIs #h-bar() .NET #h-bar() VBA],
  tags: ("Java", "JS", "IT")
)

#cv-skill-with-level(
  type: [DevOps & Infrastruktur],
  level: 3,
  info: [Docker #h-bar() Kubernetes #h-bar() CI/CD #h-bar() Jenkins #h-bar() Git #h-bar() SVN #h-bar() Linux #h-bar() UNIX],
  tags: ("DevOps", "CI", "IT")
)

#cv-skill-with-level(
  type: [Methodik & Management],
  level: 3,
  info: [Agile (Scrum, Kanban) #h-bar() Jira #h-bar() Confluence #h-bar() Architektur-Design #h-bar() Projektmanagement],
  tags: ("Scrum", "IT", "Lehre")
)


#cv-skill-with-level(
  type: [Agentic Workflows],
  level: 3,
  info: [OpenClaw #h-bar() Vibe-Engineering  #h-bar() Agentic Coding],
  tags: ("OpenClaw", "Vibe-Engineering", "Agentic Coding", "IT")
)

#cv-skill-with-level(
  type: [Software & Tools],
  level: 3,
  info: [Visual Studio #h-bar() Figma (UI/UX) #h-bar() ERP-Systeme #h-bar() MS Office (Excel + OpenOffice)],
  tags: ("IT", "job","OpenSource")
)

#cv-skill(
  type: [Sprachen],
  info: [Deutsch (Muttersprache) #h-bar() Englisch (Fließend in Wort & Schrift)],
  tags: ("job", "education")
)

#cv-skill(
  type: [Persönliche Interessen],
  info: [Schach #h-bar() Entwicklung und Umsetzung von Open-Source],
  tags: ("Schach", "Open-Source", "OpenSource")
)

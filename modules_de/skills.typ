// skills.typ
#import "../helpers.typ": *
#import "@preview/brilliant-cv:3.1.2": h-bar, cv-skill-tag

#cv-section("Kenntnisse & Fähigkeiten", tags: ("IT", "job", "Java", "Python", "SQL", "DevOps", "Lehre"))

#cv-skill-with-level(
  type: [Programmierung],
  level: 4,
  info: [Python #h-bar() Java #h-bar() SQL (T-SQL, PL/SQL) #h-bar() PHP #h-bar() JavaScript #h-bar() TypeScript],
  tags: ("Python", "Java", "SQL", "PHP", "JS", "IT")
)

#cv-skill-with-level(
  type: [Frameworks & Tech],
  level: 3,
  info: [Spring #h-bar() Node.js #h-bar() React #h-bar() Angular #h-bar() REST APIs #h-bar() .NET #h-bar() VBA],
  tags: ("Java", "JS", "IT")
)

#cv-skill(
  type: [DevOps & Infrastruktur],
  info: [Docker #h-bar() Kubernetes #h-bar() CI/CD (Jenkins) #h-bar() Git #h-bar() SVN #h-bar() Linux #h-bar() UNIX],
  tags: ("DevOps", "CI", "IT")
)

#cv-skill(
  type: [Methodik & Management],
  info: [Agile (Scrum, Kanban) #h-bar() Jira #h-bar() Confluence #h-bar() Architektur-Design #h-bar() Projektmanagement],
  tags: ("Scrum", "IT", "Lehre")
)

#cv-skill(
  type: [Software & Tools],
  info: [Visual Studio #h-bar() Figma (UI/UX) #h-bar() ERP-Systeme #h-bar() MS Office (Excel + OpenOffice)],
  tags: ("IT", "job")
)

#cv-skill-with-level(
  type: [Sprachen],
  level: 5,
  info: [Deutsch (Muttersprache) #h-bar() Englisch (Fließend in Wort & Schrift)],
  tags: ("job", "education")
)

#cv-skill(
  type: [Persönliche Interessen],
  info: [Schach #h-bar() Entwicklung und Umsetzung von Open-Source],
)

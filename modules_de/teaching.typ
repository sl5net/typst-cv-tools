#import "../helpers.typ": *
// Falls du h-bar in der Beschreibung nutzt:
#import "@preview/brilliant-cv:3.1.2": h-bar

#cv-section("Kursleiter / Lehrer / Dozent", tags: ("Lehre", "Java" , "Python", "Dozent", "VHS"))

#cv-entry(
  title: [Kursleiter für Python & KI],
  location: [Tübingen],
  society: [VHS Tübingen],
  date: [2026 - Heute],
  description: list(
    [Fokus auf angewandte KI],[Prompt Engineering für Nicht-Entwickler],[Automatisierung mit Python]
  ),
  tags: ("KI", "Python", "regex", "Dozent", "Lehre"),
)

#cv-entry(
  title: [Gastreferent (Linux-Tag)],
  location: [Reutlingen],
  society: [Stadtbücherei Reutlingen],
  date: [April 2026],
  description: list(
    [Fachvortrag und Live-Präsentation zum Thema "Moderne Spracherkennung und KI-Assistenz"],
    [Vorstellung der lokal betriebenen Open-Source-Lösung *sl5net Aura* im Kontext von Datenschutz und Barrierefreiheit]
  ),
  tags: ("KI", "OpenSource", "Linux", "Spracherkennung", "Vortrag"),
)

#cv-entry(
  title: [Langjähriger IT-Trainer für komplexe Themenbereiche],
  society: [Future Training Reutlingen & Consulting GmbH / VHS Heidelberg],
  location: [Reutlingen & Heidelberg],
  date: [2001 - 2021],
  description: list(
    [Vermittlung von Fullstack-Grundlagen (Java, JS, PHP, C++, SQL, MySQL) ],[Vermittlung von Grundlagen in Python]
  ),
  tags: ("SQL", "Java", "PHP", "JS", "Python"),
)

#cv-section("Community & Expertise")

#cv-entry(
  title: [Anerkannter Experte & Trusted User],
  society: [Stack Overflow (sl5net)],
  date: [2012 – heute],
  location: [Online],
  description: list(
    [*Globaler Impact:* Über 530.000 erreichte Entwickler durch technische Problemlösungen (Top 10% in Kern-Tags wie Regex und Automation).],
    [*Fachliche Schwerpunkte:* komplexer Textanalyse (Regex), Linux-Systemadministration, systemübergreifender Automatisierung.],
    [*Qualitätssicherung:* Inhaber erweiterter Community-Rechte ("Socratic" & "Trusted User") zur Moderation und Qualitätssicherung der Plattform.],
    [Profil: #link("https://stackoverflow.com/users/2891692/sl5net")[stackoverflow.com/sl5net]]
  ),
  tags: ("Regex", "Linux", "Automation", "Python", "Problem-Solving","SQL", "Java", "PHP", "JS", "Python")
)

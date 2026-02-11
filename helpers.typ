#import "@preview/brilliant-cv:3.1.2": cv-entry as org-entry, cv-section as org-section, h-bar, cv-honor as org-honor, cv-skill as org-skill, cv-skill-with-level as org-skill-level

#let metadata = toml("./metadata.toml")
#let filter-input = sys.inputs.at("filter", default: "")

// Hilfsfunktion für die Sichtbarkeit
#let is-visible(tags) = {
  if filter-input == "" { return true }
  let tag-list = if type(tags) == array { tags } else if type(tags) == str { (tags,) } else { () }
  tag-list.any(t => str(t).match(regex(filter-input)) != none)
}

// Gefilterte Sektion
#let cv-section(title, tags: ()) = {
  if is-visible(tags) {
    org-section.with(metadata: metadata)(title)
  }
}

// Gefilterte Einträge
#let _filtered(args, org-func) = {
  let named = args.named()
  if is-visible(named.at("tags", default: ())) {
    if "tags" in named { let _ = named.remove("tags") }
    org-func(..args.pos(), ..named)
  }
}

#let cv-entry(..args) = { _filtered(args, org-entry.with(metadata: metadata)) }
#let cv-skill(..args) = { _filtered(args, org-skill) }
#let cv-skill-with-level(..args) = { _filtered(args, org-skill-level) }
#let cv-honor(..args) = { _filtered(args, org-honor.with(metadata: metadata)) }


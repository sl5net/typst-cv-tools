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

// Erweiterte Filter-Funktion mit optionalem Tech-Stack
#let _filtered(args, org-func) = {
  let named = args.named()
  let tags = named.at("tags", default: ())

  // Tags aus den Argumenten für die Original-Funktion entfernen
  if "tags" in named { let _ = named.remove("tags") }



  if is-visible(tags) {
    // Entferne tags für die originale Funktion, falls nötig
    if "tags" in named { let _ = named.remove("tags") }

    // 1. Den eigentlichen Eintrag rendern
    org-func(..args.pos(), ..named)

    // 2. Tech-Stack anzeigen
    if sys.inputs.at("show_stack", default: "false") == "true" and tags.len() > 0 {

       // DEFINITION: Welche Tags sollen NICHT gedruckt werden?
       let hidden_tags = ("edu_it", "education", "job", "civil-service", "social-care")

       // Filtere die Tags für die Anzeige
       let display_tags = tags.filter(t => t not in hidden_tags)

       // Nur anzeigen, wenn nach dem Filtern noch was übrig ist
       if display_tags.len() > 0 {
           v(-0.6em)
           pad(left: 1em, bottom: 0.6em, text(size: 0.75em, fill: gray.darken(20%), style: "italic")[
             Stack: #display_tags.join(" • ")
           ])
       }
    }


  }
}



#let cv-entry(..args) = {
  let named = args.named()

  // FIX: Wenn Description fehlt oder leer ist -> explizit 'none' setzen
  // Damit überschreiben wir den Default-Wert des Templates.
  if "description" not in named or named.at("description") == list() or named.at("description") == [] {
     let _ = named.insert("description", none)
  }

  // Neue Argumente zusammenbauen und weiterreichen
  let new-args = arguments(..args.pos(), ..named)

  _filtered(new-args, org-entry.with(metadata: metadata))
}








#let cv-skill(..args) = { _filtered(args, org-skill) }
#let cv-skill-with-level(..args) = { _filtered(args, org-skill-level) }
#let cv-honor(..args) = { _filtered(args, org-honor.with(metadata: metadata)) }


// cover_letter.typ
#import "@preview/brilliant-cv:3.1.2": cv

#let metadata = toml("metadata.toml")

// Überschreibe header_quote für Anschreiben
#let metadata = metadata + (lang: metadata.lang + (de: metadata.lang.de + (header_quote: "")))

#let metadata = metadata + (lang: metadata.lang + (de: metadata.lang.de + (cv_footer: "Anschreiben")))


#show: cv.with(
    metadata,
    profile-photo: image("assets/avatar.png"),
)

#let lang = metadata.language

// CLI-Input
#let body_file = sys.inputs.at("file", default: "anschreiben.txt")
#let body_text = read(body_file).replace("#", "\#")

// Briefinhalt mit Formatierung
#set text(size: 11pt)
#set par(justify: true, leading: 0.8em)

// Parse den Text als Typst-Markup
#eval(body_text, mode: "markup")

// Unterschrift
#v(1cm)
Wannweil, den #datetime.today().display("[day].[month].[year]")
#v(0.5cm)
#image("assets/signature.png", width: 3.5cm)
#v(-0.5cm)
#line(length: 4cm, stroke: 0.5pt)
#v(-0.2cm)
#metadata.personal.first_name #metadata.personal.last_name

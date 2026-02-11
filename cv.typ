#import "helpers.typ": *
#import "@preview/brilliant-cv:3.1.2": cv

#show: cv.with(metadata, profile-photo: image("assets/avatar.png"))

#let lang = metadata.language
#let modules = ("education", "professional", "teaching", "projects", "certificates", "skills", "interests")

#for name in modules {
  include "modules_" + lang + "/" + name + ".typ"
}



// 6. Unterschrift
#v(1cm)
Wannweil, den #datetime.today().display("[day].[month].[year]")
#v(0.5cm)
#image("assets/signature.png", width: 3.5cm)
#v(-0.5cm)
#line(length: 4cm, stroke: 0.5pt)
#v(-0.2cm)
#metadata.personal.first_name #metadata.personal.last_name

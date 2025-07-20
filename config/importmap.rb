# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# GSAP Animation Library
pin "gsap", to: "https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"

# D3.js for advanced data visualization
pin "d3", to: "https://cdnjs.cloudflare.com/ajax/libs/d3/7.9.0/d3.min.js"

# Leaflet for GIS mapping
pin "leaflet", to: "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js"

# Chart.js for charts
pin "chart.js", to: "https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.min.js"

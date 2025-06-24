resource "cloudflare_record" "vercel_frontend" {
  zone_id = var.cloudflare_zone_id
  name    = "emotra"
  type    = "CNAME"
  content = "cname.vercel-dns.com"
  proxied = false
}

resource "cloudflare_record" "render_backend" {
  zone_id = var.cloudflare_zone_id
  name    = "emotra-api"
  type    = "CNAME"
  content = "your-backend.onrender.com"  # ← TODO Renderで発行されたドメインに変更
  proxied = true
}

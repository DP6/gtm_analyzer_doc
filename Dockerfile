# Serve o build estático (feito no runner do Actions; ver .github/workflows/deploy.yml).
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY build /usr/share/nginx/html

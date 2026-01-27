FROM nginx:alpine

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Remove default nginx config
RUN rm -f /etc/nginx/conf.d/default.conf.default

# Expose port 8080 (Azure App Service standard)
EXPOSE 8080

# Start nginx
CMD ["nginx", "-g", "daemon off;"]

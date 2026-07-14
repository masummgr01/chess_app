# Step 1: Use the Nginx image
FROM nginx:alpine

# Step 2: Copy your static web files into the Nginx html directory
# This assumes your Flutter/React build output is in a folder named 'build/web'
COPY build/web /usr/share/nginx/html

# Step 3: Create a custom Nginx configuration to change the port to 7860
# Nginx defaults to 80, but Hugging Face needs 7860
RUN sed -i 's/listen  80;/listen 7860;/g' /etc/nginx/conf.d/default.conf

# Step 4: Expose port 7860
EXPOSE 7860

# Step 5: Start Nginx
CMD ["nginx", "-g", "daemon off;"]
# Use the official Nginx image as the base image.
FROM nginx:latest

# Copy the hello.txt file from the repository to the Nginx html directory
COPY hello.txt /var/www/

# Expose port 80
EXPOSE 80

# Start Nginx when the container launches
CMD ["nginx", "-g", "daemon off;"]

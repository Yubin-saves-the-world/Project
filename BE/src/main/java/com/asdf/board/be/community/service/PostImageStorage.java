package com.asdf.board.be.community.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

@Service
public class PostImageStorage {

    private final Path uploadDir;

    public PostImageStorage(@Value("${vitality.upload.dir:uploads}") String uploadDir) throws IOException {
        this.uploadDir = Paths.get(uploadDir).toAbsolutePath();
        Files.createDirectories(this.uploadDir);
    }

    public String store(MultipartFile file) throws IOException {
        String ext = getExtension(file.getOriginalFilename());
        String key = UUID.randomUUID() + ext;
        Files.copy(file.getInputStream(), uploadDir.resolve(key));
        return key;
    }

    public void delete(String storageKey) {
        try {
            Files.deleteIfExists(uploadDir.resolve(storageKey));
        } catch (IOException ignored) {}
    }

    private String getExtension(String filename) {
        if (filename == null) return ".jpg";
        int dot = filename.lastIndexOf('.');
        return dot >= 0 ? filename.substring(dot).toLowerCase() : ".jpg";
    }
}

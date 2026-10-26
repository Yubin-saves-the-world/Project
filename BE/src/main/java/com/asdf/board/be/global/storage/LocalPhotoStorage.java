package com.asdf.board.be.global.storage;

import java.util.regex.Pattern;
import com.asdf.board.be.global.config.VitalityProperties;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class LocalPhotoStorage implements PhotoStorage {

    private static final Pattern SAFE_KEY = Pattern.compile("[A-Za-z0-9._-]+");

    private final Path root;

    public LocalPhotoStorage(VitalityProperties properties) {
        this.root = Paths.get(properties.storage().dir()).toAbsolutePath().normalize().resolve("photos");
    }

    @Override
    public void put(String key, byte[] data) {
        try {
            Files.createDirectories(root);
            Path target = resolve(key);
            Path temp = Files.createTempFile(root, "upload-", ".tmp");
            Files.write(temp, data);
            Files.move(temp, target, StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            log.error("사진 저장 실패: {}", key, e);
            throw new ApiException(ErrorCode.INTERNAL_ERROR);
        }
    }

    @Override
    public byte[] get(String key) {
        try {
            return Files.readAllBytes(resolve(key));
        } catch (IOException e) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
    }

    @Override
    public void delete(String key) {
        try {
            Files.deleteIfExists(resolve(key));
        } catch (IOException e) {
            log.error("사진 삭제 실패: {}", key, e);
            throw new ApiException(ErrorCode.INTERNAL_ERROR);
        }
    }

    private Path resolve(String key) {
        if (key == null || !SAFE_KEY.matcher(key).matches()) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        return root.resolve(key).normalize();
    }
}

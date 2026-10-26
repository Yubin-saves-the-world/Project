package com.asdf.board.be.community.repository;

import com.asdf.board.be.global.persistence.BulkWrite;
import com.asdf.board.be.community.entity.Comment;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CommentRepository extends JpaRepository<Comment, Long> {

    @Query("select c from Comment c join fetch c.user where c.post.id = :postId order by c.id asc")
    List<Comment> findAllOfPost(@Param("postId") Long postId);

    @Query("select c from Comment c join fetch c.user where c.id = :id")
    Optional<Comment> findWithUser(@Param("id") Long id);

    boolean existsByParentId(Long parentId);

    long countByParentId(Long parentId);

    long countByPostIdAndIsDeletedFalse(Long postId);

    @BulkWrite
    @Query("update Comment c set c.hiddenAt = :at where c.id = :id and c.hiddenAt is null")
    void hide(@Param("id") Long id, @Param("at") LocalDateTime at);

    @BulkWrite
    @Query("update Comment c set c.hiddenAt = null where c.id = :id")
    void unhide(@Param("id") Long id);

    @BulkWrite
    @Query("delete from Comment c where c.post.id = :postId and c.parent is not null")
    void deleteRepliesOfPost(@Param("postId") Long postId);

    @BulkWrite
    @Query("delete from Comment c where c.post.id = :postId")
    void deleteAllOfPost(@Param("postId") Long postId);

    @BulkWrite
    @Query("delete from Comment c where c.id = :id")
    void deleteRow(@Param("id") Long id);
}

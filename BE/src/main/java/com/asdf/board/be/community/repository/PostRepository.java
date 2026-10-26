package com.asdf.board.be.community.repository;

import com.asdf.board.be.global.persistence.BulkWrite;
import com.asdf.board.be.community.entity.Post;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostRepository extends JpaRepository<Post, Long> {

    String NOT_BLOCKED = "p.user.id not in (select b.id.blockedId from Block b where b.id.blockerId = :me)";

    @Query(value = "select p from Post p join fetch p.user where p.hiddenAt is null and " + NOT_BLOCKED
            + " order by p.isPinned desc, p.createdAt desc, p.id desc",
            countQuery = "select count(p) from Post p where p.hiddenAt is null and " + NOT_BLOCKED)
    Page<Post> visible(@Param("me") Long me, Pageable pageable);

    @Query(value = "select p from Post p join fetch p.user where p.hiddenAt is null and p.category = :category and " + NOT_BLOCKED
            + " order by p.isPinned desc, p.createdAt desc, p.id desc",
            countQuery = "select count(p) from Post p where p.hiddenAt is null and p.category = :category and " + NOT_BLOCKED)
    Page<Post> visibleByCategory(@Param("me") Long me, @Param("category") Post.Category category, Pageable pageable);

    @Query("select p from Post p join fetch p.user where p.id = :id")
    Optional<Post> findWithUser(@Param("id") Long id);

    @BulkWrite
    @Query("update Post p set p.viewCount = p.viewCount + 1 where p.id = :id")
    void increaseView(@Param("id") Long id);

    @BulkWrite
    @Query("update Post p set p.likeCount = :count where p.id = :id")
    void setLikeCount(@Param("id") Long id, @Param("count") int count);

    @BulkWrite
    @Query("update Post p set p.commentCount = :count where p.id = :id")
    void setCommentCount(@Param("id") Long id, @Param("count") int count);

    @BulkWrite
    @Query("update Post p set p.hiddenAt = :at where p.id = :id and p.hiddenAt is null")
    void hide(@Param("id") Long id, @Param("at") java.time.LocalDateTime at);

    @BulkWrite
    @Query("update Post p set p.hiddenAt = null where p.id = :id")
    void unhide(@Param("id") Long id);

    @BulkWrite
    @Query("delete from Post p where p.id = :id")
    void deleteRow(@Param("id") Long id);
}

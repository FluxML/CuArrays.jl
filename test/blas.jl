using CuArrays.BLAS: band, bandex

@testset "BLAS" begin

    m = 20
    n = 35
    k = 13

#################
# level 1 tests #
#################

    @testset "Level 1 with element type $T" for T in [Float32, Float64, ComplexF32, ComplexF64]
        A = CuArray(rand(T, m))
        B = CuArray{T}(m)
        CuArrays.BLAS.blascopy!(m,A,1,B,1)
        @test Array(A) == Array(B)

        @test testf(rmul!, rand(T, 6, 9, 3), Ref(rand()))
        @test testf(dot, rand(T, m), rand(T, m))
        @test testf(*, transpose(rand(T, m)), rand(T, m))
        @test testf(*, rand(T, m)', rand(T, m))
        @test testf(norm, rand(T, m))
        @test testf(BLAS.asum, rand(T, m))
        @test testf(BLAS.axpy!, Ref(rand()), rand(T, m), rand(T, m))

        if T <: Real
            @test testf(argmin, rand(T, m))
            @test testf(argmax, rand(T, m))
        end
    end # level 1 testset

    @testset "Level 2" begin

        @testset "gemv with element type $T" for T in [Float32, Float64, ComplexF32, ComplexF64]
            @test testf(*, rand(T, m, n), rand(T, n))
            @test testf(*, transpose(rand(T, m, n)), rand(T, m))
            @test testf(*, rand(T, m, n)', rand(T, m))
        end

        @testset "gbmv! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # parameters
            alpha = convert(elty,2)
            beta = convert(elty,3)
            # bands
            ku = 2
            kl = 3
            # generate banded matrix
            A = rand(elty,m,n)
            A = bandex(A,kl,ku)
            # get packed format
            Ab = band(A,kl,ku)
            d_Ab = CuArray(Ab)
            # test y = alpha*A*x + beta*y
            x = rand(elty,n)
            d_x = CuArray(x)
            y = rand(elty,m)
            d_y = CuArray(y)
            CuArrays.BLAS.gbmv!('N',m,kl,ku,alpha,d_Ab,d_x,beta,d_y)
            BLAS.gbmv!('N',m,kl,ku,alpha,Ab,x,beta,y)
            h_y = Array(d_y)
            @test y ≈ h_y
            # test y = alpha*transpose(A)*x + beta*y
            x = rand(elty,n)
            d_x = CuArray(x)
            y = rand(elty,m)
            d_y = CuArray(y)
            CuArrays.BLAS.gbmv!('T',m,kl,ku,alpha,d_Ab,d_y,beta,d_x)
            BLAS.gbmv!('T',m,kl,ku,alpha,Ab,y,beta,x)
            h_x = Array(d_x)
            @test x ≈ h_x
            # test y = alpha*A'*x + beta*y
            x = rand(elty,n)
            d_x = CuArray(x)
            y = rand(elty,m)
            d_y = CuArray(y)
            CuArrays.BLAS.gbmv!('C',m,kl,ku,alpha,d_Ab,d_y,beta,d_x)
            BLAS.gbmv!('C',m,kl,ku,alpha,Ab,y,beta,x)
            h_x = Array(d_x)
            @test x ≈ h_x
        end

        @testset "gbmv with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # parameters
            alpha = convert(elty,2)
            # bands
            ku = 2
            kl = 3
            # generate banded matrix
            A = rand(elty,m,n)
            A = bandex(A,kl,ku)
            # get packed format
            Ab = band(A,kl,ku)
            d_Ab = CuArray(Ab)
            # test y = alpha*A*x
            x = rand(elty,n)
            d_x = CuArray(x)
            d_y = CuArrays.BLAS.gbmv('N',m,kl,ku,alpha,d_Ab,d_x)
            y = zeros(elty,m)
            y = BLAS.gbmv('N',m,kl,ku,alpha,Ab,x)
            h_y = Array(d_y)
            @test y ≈ h_y
        end

        @testset "symv! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # parameters
            alpha = convert(elty,2)
            beta = convert(elty,3)
            # generate symmetric matrix
            A = rand(elty,m,m)
            A = A + transpose(A)
            # generate vectors
            x = rand(elty,m)
            y = rand(elty,m)
            # copy to device
            d_A = CuArray(A)
            d_x = CuArray(x)
            d_y = CuArray(y)
            # execute on host
            BLAS.symv!('U',alpha,A,x,beta,y)
            # execute on device
            CuArrays.BLAS.symv!('U',alpha,d_A,d_x,beta,d_y)
            # compare results
            h_y = Array(d_y)
            @test y ≈ h_y
        end

        @testset "symv with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate symmetric matrix
            A = rand(elty,m,m)
            A = A + transpose(A)
            # generate vectors
            x = rand(elty,m)
            # copy to device
            d_A = CuArray(A)
            d_x = CuArray(x)
            # execute on host
            y = BLAS.symv('U',A,x)
            # execute on device
            d_y = CuArrays.BLAS.symv('U',d_A,d_x)
            # compare results
            h_y = Array(d_y)
            @test y ≈ h_y
        end

        @testset "hemv! with element type $elty" for elty in [ComplexF32, ComplexF64]
            # parameters
            alpha = convert(elty,2)
            beta = convert(elty,3)
            # generate hermitian matrix
            A = rand(elty,m,m)
            A = A + A'
            # generate vectors
            x = rand(elty,m)
            y = rand(elty,m)
            # copy to device
            d_A = CuArray(A)
            d_x = CuArray(x)
            d_y = CuArray(y)
            # execute on host
            BLAS.hemv!('U',alpha,A,x,beta,y)
            # execute on device
            CuArrays.BLAS.hemv!('U',alpha,d_A,d_x,beta,d_y)
            # compare results
            h_y = Array(d_y)
            @test y ≈ h_y
        end

        @testset "hemv with element type $elty" for elty in [ComplexF32, ComplexF64]
            # generate hermitian matrix
            A = rand(elty,m,m)
            A = A + A'
            # generate vectors
            x = rand(elty,m)
            # copy to device
            d_A = CuArray(A)
            d_x = CuArray(x)
            # execute on host
            y = BLAS.hemv('U',A,x)
            # execute on device
            d_y = CuArrays.BLAS.hemv('U',d_A,d_x)
            # compare results
            h_y = Array(d_y)
            @test y ≈ h_y
        end

        @testset "sbmv! with element type $elty" for elty in [Float32, Float64]
            # parameters
            alpha = convert(elty,3)
            beta = convert(elty,2.5)
            # generate symmetric matrix
            A = rand(elty,m,m)
            A = A + A'
            # restrict to 3 bands
            nbands = 3
            @test m >= 1+nbands
            A = bandex(A,nbands,nbands)
            # convert to 'upper' banded storage format
            AB = band(A,0,nbands)
            # construct x and y
            x = rand(elty,m)
            y = rand(elty,m)
            # move to host
            d_AB = CuArray(AB)
            d_x = CuArray(x)
            d_y = CuArray(y)
            # sbmv!
            CuArrays.BLAS.sbmv!('U',nbands,alpha,d_AB,d_x,beta,d_y)
            y = alpha*(A*x) + beta*y
            # compare
            h_y = Array(d_y)
            @test y ≈ h_y
        end

        @testset "sbmv with element type $elty" for elty in [Float32, Float64]
            # parameters
            alpha = convert(elty,3)
            beta = convert(elty,2.5)
            # generate symmetric matrix
            A = rand(elty,m,m)
            A = A + A'
            # restrict to 3 bands
            nbands = 3
            @test m >= 1+nbands
            A = bandex(A,nbands,nbands)
            # convert to 'upper' banded storage format
            AB = band(A,0,nbands)
            # construct x and y
            x = rand(elty,m)
            y = rand(elty,m)
            # move to host
            d_AB = CuArray(AB)
            d_x = CuArray(x)
            # sbmv!
            d_y = CuArrays.BLAS.sbmv('U',nbands,d_AB,d_x)
            y = A*x
            # compare
            h_y = Array(d_y)
            @test y ≈ h_y
        end

        @testset "hbmv! with element type $elty" for elty in [ComplexF32, ComplexF64]
            # parameters
            alpha = rand(elty)
            beta = rand(elty)
            # generate Hermitian matrix
            A = rand(elty,m,m)
            A = A + adjoint(A)
            # restrict to 3 bands
            nbands = 3
            @test m >= 1+nbands
            A = bandex(A,nbands,nbands)
            # convert to 'upper' banded storage format
            AB = band(A,0,nbands)
            # construct x and y
            x = rand(elty,m)
            y = rand(elty,m)
            # move to host
            d_AB = CuArray(AB)
            d_x = CuArray(x)
            d_y = CuArray(y)
            # hbmv!
            CuArrays.BLAS.hbmv!('U',nbands,alpha,d_AB,d_x,beta,d_y)
            y = alpha*(A*x) + beta*y
            # compare
            h_y = Array(d_y)
            @test y ≈ h_y
        end

        @testset "hbmv with element type $elty" for elty in [ComplexF32, ComplexF64]
            # parameters
            alpha = rand(elty)
            beta = rand(elty)
            # generate Hermitian matrix
            A = rand(elty,m,m)
            A = A + adjoint(A)
            # restrict to 3 bands
            nbands = 3
            @test m >= 1+nbands
            A = bandex(A,nbands,nbands)
            # convert to 'upper' banded storage format
            AB = band(A,0,nbands)
            # construct x and y
            x = rand(elty,m)
            y = rand(elty,m)
            # move to host
            d_AB = CuArray(AB)
            d_x = CuArray(x)
            # hbmv
            d_y = CuArrays.BLAS.hbmv('U',nbands,d_AB,d_x)
            y = A*x
            # compare
            h_y = Array(d_y)
            @test y ≈ h_y
        end

        @testset "tbmv! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate triangular matrix
            A = rand(elty,m,m)
            # restrict to 3 bands
            nbands = 3
            @test m >= 1+nbands
            A = bandex(A,0,nbands)
            # convert to 'upper' banded storage format
            AB = band(A,0,nbands)
            # construct x and y
            x = rand(elty,m)
            # move to host
            d_AB = CuArray(AB)
            d_x = CuArray(x)
            # tbmv!
            CuArrays.BLAS.tbmv!('U','N','N',nbands,d_AB,d_x)
            x = A*x
            # compare
            h_x = Array(d_x)
            @test x ≈ h_x
        end

        @testset "tbmv with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate triangular matrix
            A = rand(elty,m,m)
            # restrict to 3 bands
            nbands = 3
            @test m >= 1+nbands
            A = bandex(A,0,nbands)
            # convert to 'upper' banded storage format
            AB = band(A,0,nbands)
            # construct x
            x = rand(elty,m)
            # move to host
            d_AB = CuArray(AB)
            d_x = CuArray(x)
            # tbmv!
            d_y = CuArrays.BLAS.tbmv!('U','N','N',nbands,d_AB,d_x)
            y = A*x
            # compare
            h_y = Array(d_y)
            @test y ≈ h_y
        end

        @testset "tbsv! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate triangular matrix
            A = rand(elty,m,m)
            # restrict to 3 bands
            nbands = 3
            @test m >= 1+nbands
            A = bandex(A,0,nbands)
            # convert to 'upper' banded storage format
            AB = band(A,0,nbands)
            # generate vector
            x = rand(elty,m)
            # move to device
            d_AB = CuArray(AB)
            d_x = CuArray(x)
            #tbsv!
            CuArrays.BLAS.tbsv!('U','N','N',nbands,d_AB,d_x)
            x = A\x
            # compare
            h_x = Array(d_x)
            @test x ≈ h_x
        end

        @testset "tbsv with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate triangular matrix
            A = rand(elty,m,m)
            # restrict to 3 bands
            nbands = 3
            @test m >= 1+nbands
            A = bandex(A,0,nbands)
            # convert to 'upper' banded storage format
            AB = band(A,0,nbands)
            # generate vector
            x = rand(elty,m)
            # move to device
            d_AB = CuArray(AB)
            d_x = CuArray(x)
            #tbsv
            d_y = CuArrays.BLAS.tbsv('U','N','N',nbands,d_AB,d_x)
            y = A\x
            # compare
            h_y = Array(d_y)
            @test y ≈ h_y
        end

        @testset "trmv! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate triangular matrix
            A = rand(elty,m,m)
            A = triu(A)
            # generate vector
            x = rand(elty,m)
            # move to device
            d_A = CuArray(A)
            d_x = CuArray(x)
            # execute trmv!
            CuArrays.BLAS.trmv!('U','N','N',d_A,d_x)
            x = A*x
            # compare
            h_x = Array(d_x)
            @test x ≈ h_x
        end

        @testset "trmv with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate triangular matrix
            A = rand(elty,m,m)
            A = triu(A)
            # generate vector
            x = rand(elty,m)
            # move to device
            d_A = CuArray(A)
            d_x = CuArray(x)
            # execute trmv!
            d_y = CuArrays.BLAS.trmv('U','N','N',d_A,d_x)
            y = A*x
            # compare
            h_y = Array(d_y)
            @test y ≈ h_y
        end

        @testset "trsv! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate triangular matrix
            A = rand(elty,m,m)
            A = triu(A)
            # generate vector
            x = rand(elty,m)
            # move to device
            d_A = CuArray(A)
            d_x = CuArray(x)
            # execute trsv!
            CuArrays.BLAS.trsv!('U','N','N',d_A,d_x)
            x = A\x
            # compare
            h_x = Array(d_x)
            @test x ≈ h_x
        end

        @testset "trsv with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate triangular matrix
            A = rand(elty,m,m)
            A = triu(A)
            # generate vector
            x = rand(elty,m)
            # move to device
            d_A = CuArray(A)
            d_x = CuArray(x)
            # execute trsv!
            d_y = CuArrays.BLAS.trsv('U','N','N',d_A,d_x)
            y = A\x
            # compare
            h_y = Array(d_y)
            @test y ≈ h_y
        end

        @testset "ger! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # construct matrix and vectors
            A = rand(elty,m,n)
            x = rand(elty,m)
            y = rand(elty,n)
            alpha = convert(elty,2)
            # move to device
            d_A = CuArray(A)
            d_x = CuArray(x)
            d_y = CuArray(y)
            # perform rank one update
            CuArrays.BLAS.ger!(alpha,d_x,d_y,d_A)
            A = (alpha*x)*y' + A
            # move to host and compare
            h_A = Array(d_A)
            @test A ≈ h_A
        end

        @testset "syr! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # construct matrix and vector
            A = rand(elty,m,m)
            A = A + transpose(A)
            x = rand(elty,m)
            alpha = convert(elty,2)
            # move to device
            d_A = CuArray(A)
            d_x = CuArray(x)
            # perform rank one update
            CuArrays.BLAS.syr!('U',alpha,d_x,d_A)
            A = (alpha*x)*transpose(x) + A
            # move to host and compare upper triangles
            h_A = Array(d_A)
            A = triu(A)
            h_A = triu(h_A)
            @test A ≈ h_A
        end

        @testset "her! with element type $elty" for elty in [ComplexF32, ComplexF64]
            local m = 2
            # construct matrix and vector
            A = rand(elty,m,m)
            A = A + A'
            x = rand(elty,m)
            alpha = convert(elty,2)
            # move to device
            d_A = CuArray(A)
            d_x = CuArray(x)
            # perform rank one update
            CuArrays.BLAS.her!('U',alpha,d_x,d_A)
            A = (alpha*x)*x' + A
            # move to host and compare upper triangles
            h_A = Array(d_A)
            A = triu(A)
            h_A = triu(h_A)
            @test A ≈ h_A
        end

        @testset "her2! with element type $elty" for elty in [ComplexF32, ComplexF64]
            local m = 2
            # construct matrix and vector
            A = rand(elty,m,m)
            A = A + A'
            x = rand(elty,m)
            y = rand(elty,m)
            alpha = convert(elty,2)
            # move to device
            d_A = CuArray(A)
            d_x = CuArray(x)
            d_y = CuArray(y)
            # perform rank one update
            CuArrays.BLAS.her2!('U',alpha,d_x,d_y,d_A)
            A = (alpha*x)*y' + y*(alpha*x)' + A
            # move to host and compare upper triangles
            h_A = Array(d_A)
            A = triu(A)
            h_A = triu(h_A)
            @test A ≈ h_A
        end
    end # level 2 testset

    @testset "Level 3" begin

        @testset "gemm! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # parameters
            alpha = rand(elty)
            beta = rand(elty)
            # generate matrices
            A = rand(elty,m,k)
            B = rand(elty,k,n)
            C1 = rand(elty,m,n)
            C2 = copy(C1)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            d_C1 = CuArray(C1)
            d_C2 = CuArray(C2)
            # C = (alpha*A)*B + beta*C
            CuArrays.BLAS.gemm!('N','N',alpha,d_A,d_B,beta,d_C1)
            mul!(d_C2, d_A, d_B)
            h_C1 = Array(d_C1)
            h_C2 = Array(d_C2)
            C1 = (alpha*A)*B + beta*C1
            C2 = A*B
            # compare
            @test C1 ≈ h_C1
            @test C2 ≈ h_C2
        end

        @testset "gemm with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate matrices
            A = rand(elty,m,k)
            B = rand(elty,k,n)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            # C = (alpha*A)*B + beta*C
            d_C = CuArrays.BLAS.gemm('N','N',d_A,d_B)
            C = A*B
            C2 = d_A * d_B
            # compare
            h_C = Array(d_C)
            h_C2 = Array(C2)
            @test C ≈ h_C
            @test C ≈ h_C2
        end

        @testset "gemm_batched! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # parameters
            alpha = rand(elty)
            beta = rand(elty)
            # generate matrices
            A = [rand(elty,m,k) for i in 1:10]
            B = [rand(elty,k,n) for i in 1:10]
            C = [rand(elty,m,n) for i in 1:10]
            # move to device
            d_A = CuArray{elty, 2}[]
            d_B = CuArray{elty, 2}[]
            d_C = CuArray{elty, 2}[]
            for i in 1:length(A)
                push!(d_A,CuArray(A[i]))
                push!(d_B,CuArray(B[i]))
                push!(d_C,CuArray(C[i]))
            end
            # C = (alpha*A)*B + beta*C
            CuArrays.BLAS.gemm_batched!('N','N',alpha,d_A,d_B,beta,d_C)
            for i in 1:length(d_C)
                C[i] = (alpha*A[i])*B[i] + beta*C[i]
                h_C = Array(d_C[i])
                #compare
                @test C[i] ≈ h_C
            end
        end

        @testset "gemm_batched with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate matrices
            A = [rand(elty,m,k) for i in 1:10]
            B = [rand(elty,k,n) for i in 1:10]
            # move to device
            d_A = CuArray{elty, 2}[]
            d_B = CuArray{elty, 2}[]
            for i in 1:length(A)
                push!(d_A, CuArray(A[i]))
                push!(d_B, CuArray(B[i]))
            end
            # C = A*B
            d_C = CuArrays.BLAS.gemm_batched('N','N',d_A,d_B)
            for i in 1:length(A)
                C = A[i]*B[i]
                h_C = Array(d_C[i])
                @test C ≈ h_C
            end
        end

        @testset "symm! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # parameters
            alpha = rand(elty)
            beta = rand(elty)
            # generate matrices
            A = rand(elty,m,m)
            A = A + transpose(A)
            B = rand(elty,m,n)
            C = rand(elty,m,n)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            d_C = CuArray(C)
            # C = (alpha*A)*B + beta*C
            CuArrays.BLAS.symm!('L','U',alpha,d_A,d_B,beta,d_C)
            C = (alpha*A)*B + beta*C
            # compare
            h_C = Array(d_C)
            @test C ≈ h_C
        end

        @testset "symm with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate matrices
            A = rand(elty,m,m)
            A = A + transpose(A)
            B = rand(elty,m,n)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            # C = (alpha*A)*B + beta*C
            d_C = CuArrays.BLAS.symm('L','U',d_A,d_B)
            C = A*B
            # compare
            h_C = Array(d_C)
            @test C ≈ h_C
        end

        @testset "syrk! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate matrices
            A = rand(elty,m,k)
            C = rand(elty,m,m)
            C = C + transpose(C)
            # parameters
            alpha = rand(elty)
            beta = rand(elty)
            # move to device
            d_A = CuArray(A)
            d_C = CuArray(C)
            # C = (alpha*A)*transpose(A) + beta*C
            CuArrays.BLAS.syrk!('U','N',alpha,d_A,beta,d_C)
            C = (alpha*A)*transpose(A) + beta*C
            C = triu(C)
            # move to host and compare
            h_C = Array(d_C)
            h_C = triu(C)
            @test C ≈ h_C
        end

        @testset "syrk with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate matrices
            A = rand(elty,m,k)
            # move to device
            d_A = CuArray(A)
            # C = A*transpose(A)
            d_C = CuArrays.BLAS.syrk('U','N',d_A)
            C = A*transpose(A)
            C = triu(C)
            # move to host and compare
            h_C = Array(d_C)
            h_C = triu(C)
            @test C ≈ h_C
        end

        @testset "herk! with element type $elty" for elty in [ComplexF32, ComplexF64]
            # generate matrices
            A = rand(elty,m,k)
            C = rand(elty,m,m)
            C = C + C'
            # parameters
            alpha = rand(elty)
            beta = rand(elty)
            # move to device
            d_A = CuArray(A)
            d_C = CuArray(C)
            CuArrays.BLAS.herk!('U','N',alpha,d_A,beta,d_C)
            C = alpha*(A*A') + beta*C
            C = triu(C)
            # move to host and compare
            h_C = Array(d_C)
            h_C = triu(C)
            @test C ≈ h_C
        end

        @testset "herk with element type $elty" for elty in [ComplexF32, ComplexF64]
            # generate matrices
            A = rand(elty,m,k)
            # move to device
            d_A = CuArray(A)
            # C = A*A'
            d_C = CuArrays.BLAS.herk('U','N',d_A)
            C = A*A'
            C = triu(C)
            # move to host and compare
            h_C = Array(d_C)
            h_C = triu(C)
            @test C ≈ h_C
        end

        @testset "syr2k! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            #local m = 3
            #local k = 1
            # generate parameters
            alpha = rand(elty)
            beta = rand(elty)
            # generate matrices
            A = rand(elty,m,k)
            B = rand(elty,m,k)
            C = rand(elty,m,m)
            C = C + transpose(C)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            d_C = CuArray(C)
            # compute
            #C = alpha*(A*transpose(B)) + conj(alpha)*(B*transpose(A)) + beta*C
            C = alpha*(A*transpose(B) + B*transpose(A)) + beta*C
            CuArrays.BLAS.syr2k!('U','N',alpha,d_A,d_B,beta,d_C)
            # move back to host and compare
            C = triu(C)
            h_C = Array(d_C)
            h_C = triu(h_C)

            @test C ≈ h_C
        end

        @testset "syr2k with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate parameters
            alpha = rand(elty)
            # generate matrices
            A = rand(elty,m,k)
            B = rand(elty,m,k)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            # compute
            #C = alpha*(A*transpose(B)) + conj(alpha)*(B*transpose(A)) + beta*C
            C = alpha*(A*transpose(B) + B*transpose(A))
            d_C = CuArrays.BLAS.syr2k('U','N',alpha,d_A,d_B)
            # move back to host and compare
            C = triu(C)
            h_C = Array(d_C)
            h_C = triu(h_C)
            @test C ≈ h_C
        end

        @testset "her2k! with element types $elty1 and $elty2" for (elty1, elty2) in [(ComplexF32, Float32), (ComplexF64, Float64)]
            # generate parameters
            alpha = rand(elty1)
            beta = rand(elty2)
            # generate matrices
            A = rand(elty1,m,k)
            B = rand(elty1,m,k)
            C = rand(elty1,m,m)
            C = C + C'
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            d_C = CuArray(C)
            # compute
            #C = alpha*(A*B') + conj(alpha)*(B*A') + beta*C
            C = alpha*(A*B') + conj(alpha)*(B*A') + beta*C
            CuArrays.BLAS.her2k!('U','N',alpha,d_A,d_B,beta,d_C)
            # move back to host and compare
            C = triu(C)
            h_C = Array(d_C)
            h_C = triu(h_C)
            @test C ≈ h_C
        end

        @testset "her2k with element type $elty" for elty in [ComplexF32, ComplexF64]
            # generate matrices
            A = rand(elty,m,k)
            B = rand(elty,m,k)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            # compute
            C = A*B' + B*A'
            d_C = CuArrays.BLAS.her2k('U','N',d_A,d_B)
            # move back to host and compare
            C = triu(C)
            h_C = Array(d_C)
            h_C = triu(h_C)
            @test C ≈ h_C
        end

        @testset "trmm! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate parameter
            alpha = rand(elty)
            # generate matrices
            A = rand(elty,m,m)
            A = triu(A)
            B = rand(elty,m,n)
            C = zeros(elty,m,n)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            d_C = CuArray(C)
            # compute
            C = alpha*A*B
            CuArrays.BLAS.trmm!('L','U','N','N',alpha,d_A,d_B,d_C)
            # move to host and compare
            h_C = Array(d_C)
            @test C ≈ h_C
        end

        @testset "trmm with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate parameter
            alpha = rand(elty)
            # generate matrices
            A = rand(elty,m,m)
            A = triu(A)
            B = rand(elty,m,n)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            # compute
            C = alpha*A*B
            d_C = CuArrays.BLAS.trmm('L','U','N','N',alpha,d_A,d_B)
            # move to host and compare
            h_C = Array(d_C)
            @test C ≈ h_C
        end

        @testset "trsm! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate parameter
            alpha = rand(elty)
            # generate matrices
            A = rand(elty,m,m)
            A = triu(A)
            B = rand(elty,m,n)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            # compute
            C = alpha*(A\B)
            CuArrays.BLAS.trsm!('L','U','N','N',alpha,d_A,d_B)
            # move to host and compare
            h_C = Array(d_B)
            @test C ≈ h_C
        end

        @testset "trsm with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate parameter
            alpha = rand(elty)
            # generate matrices
            A = rand(elty,m,m)
            A = triu(A)
            B = rand(elty,m,n)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            # compute
            C = alpha*(A\B)
            d_C = CuArrays.BLAS.trsm('L','U','N','N',alpha,d_A,d_B)
            # move to host and compare
            h_C = Array(d_C)
            @test C ≈ h_C
        end

        @testset "trsm_batched! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate parameter
            alpha = rand(elty)
            # generate matrices
            A = [rand(elty,m,m) for i in 1:10]
            map!((x) -> triu(x), A, A)
            B = [rand(elty,m,n) for i in 1:10]
            # move to device
            d_A = CuArray{elty, 2}[]
            d_B = CuArray{elty, 2}[]
            for i in 1:length(A)
                push!(d_A,CuArray(A[i]))
                push!(d_B,CuArray(B[i]))
            end
            # compute
            CuArrays.BLAS.trsm_batched!('L','U','N','N',alpha,d_A,d_B)
            # move to host and compare
            for i in 1:length(d_B)
                C = alpha*(A[i]\B[i])
                h_C = Array(d_B[i])
                #compare
                @test C ≈ h_C
            end
        end

        @testset "trsm_batched with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate parameter
            alpha = rand(elty)
            # generate matrices
            A = [rand(elty,m,m) for i in 1:10]
            map!((x) -> triu(x), A, A)
            B = [rand(elty,m,n) for i in 1:10]
            # move to device
            d_A = CuArray{elty, 2}[]
            d_B = CuArray{elty, 2}[]
            for i in 1:length(A)
                push!(d_A,CuArray(A[i]))
                push!(d_B,CuArray(B[i]))
            end
            # compute
            d_C = CuArrays.BLAS.trsm_batched('L','U','N','N',alpha,d_A,d_B)
            # move to host and compare
            for i in 1:length(d_C)
                C = alpha*(A[i]\B[i])
                h_C = Array(d_C[i])
                @test C ≈ h_C
            end
        end

        @testset "hemm! with element type $elty" for elty in [ComplexF32, ComplexF64]
            # generate parameters
            alpha = rand(elty)
            beta  = rand(elty)
            # generate matrices
            A = rand(elty,m,m)
            A = A + adjoint(A)
            @test ishermitian(A)
            B = rand(elty,m,n)
            C = rand(elty,m,n)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            d_C = CuArray(C)
            # compute
            C = alpha*(A*B) + beta*C
            CuArrays.BLAS.hemm!('L','L',alpha,d_A,d_B,beta,d_C)
            # move to host and compare
            h_C = Array(d_C)
            @test C ≈ h_C
        end

        @testset "hemm with element type $elty" for elty in [ComplexF32, ComplexF64]
            # generate parameter
            alpha = rand(elty)
            # generate matrices
            A = rand(elty,m,m)
            A = A + adjoint(A)
            @test ishermitian(A)
            B = rand(elty,m,n)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            # compute
            C = alpha*(A*B)
            d_C = CuArrays.BLAS.hemm('L','U',alpha,d_A,d_B)
            # move to host and compare
            h_C = Array(d_C)
            @test C ≈ h_C
        end

        @testset "geam! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate parameters
            alpha = rand(elty)
            beta  = rand(elty)
            # generate matrices
            A = rand(elty,m,n)
            B = rand(elty,m,n)
            C = zeros(elty,m,n)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            d_C = CuArray(C)
            # compute
            C = alpha*A + beta*B
            CuArrays.BLAS.geam!('N','N',alpha,d_A,beta,d_B,d_C)
            # move to host and compare
            h_C = Array(d_C)
            @test C ≈ h_C

            #test in place versions too
            C = rand(elty,m,n)
            d_C = CuArray(C)
            C = alpha*C + beta*B
            CuArrays.BLAS.geam!('N','N',alpha,d_C,beta,d_B,d_C)
            # move to host and compare
            h_C = Array(d_C)
            @test C ≈ h_C
            C = rand(elty,m,n)
            d_C = CuArray(C)
            C = alpha*A + beta*C
            CuArrays.BLAS.geam!('N','N',alpha,d_A,beta,d_C,d_C)
            # move to host and compare
            h_C = Array(d_C)
            @test C ≈ h_C

            #test setting C to zero
            C = rand(elty,m,n)
            d_C = CuArray(C)
            alpha = zero(elty)
            beta  = zero(elty)
            CuArrays.BLAS.geam!('N','N',alpha,d_A,beta,d_B,d_C)
            h_C = Array(d_C)
            @test h_C ≈ zeros(elty,m,n)

            # bounds checking
            @test_throws DimensionMismatch CuArrays.BLAS.geam!('N','T',alpha,d_A,beta,d_B,d_C)
            @test_throws DimensionMismatch CuArrays.BLAS.geam!('T','T',alpha,d_A,beta,d_B,d_C)
            @test_throws DimensionMismatch CuArrays.BLAS.geam!('T','N',alpha,d_A,beta,d_B,d_C)
        end

        @testset "geam with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
            # generate parameter
            alpha = rand(elty)
            beta  = rand(elty)
            # generate matrices
            A = rand(elty,m,n)
            B = rand(elty,m,n)
            # move to device
            d_A = CuArray(A)
            d_B = CuArray(B)
            C = zeros(elty,m,n)
            # compute
            C = alpha*A + beta*B
            d_C = CuArrays.BLAS.geam('N','N',alpha,d_A,beta,d_B)
            # move to host and compare
            h_C = Array(d_C)
            @test C ≈ h_C
        end
    end # Level 3
end # BLAS

@testset "CUSOLVER (FixMe! should be moved to different file)" begin

    m = 20
    n = 35
    k = 13

    @testset "getrf_batched! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
        Random.seed!(1)
        local k
        # generate matrices
        A = [rand(elty,m,m) for i in 1:10]
        # move to device
        d_A = CuArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CuArray(A[i]))
        end
        pivot, info = CuArrays.BLAS.getrf_batched!(d_A, false)
        h_info = Array(info)
        for As in 1:length(d_A)
            C   = lu!(copy(A[As]), Val(false)) # lu(A[As],pivot=false)
            h_A = Array(d_A[As])
            #reconstruct L,U
            dL = Matrix(one(elty)*I, m, m)
            dU = zeros(elty,(m,m))
            k = h_info[As]
            if( k >= 0 )
                dL += tril(h_A,-k-1)
                dU += triu(h_A,k)
            end
            #compare
            @test C.L ≈ dL rtol=1e-2
            @test C.U ≈ dU rtol=1e-2
        end
        for i in 1:length(A)
            d_A[ i ] = CuArray(A[i])
        end
        pivot, info = CuArrays.BLAS.getrf_batched!(d_A, true)
        h_info = Array(info)
        h_pivot = Array(pivot)
        for As in 1:length(d_A)
            C   = lu(A[As])
            h_A = Array(d_A[As])
            #reconstruct L,U
            dL = Matrix(one(elty)*I, m, m)
            dU = zeros(elty,(m,m))
            k = h_info[As]
            if( k >= 0 )
                dL += tril(h_A,-k-1)
                dU += triu(h_A,k)
            end
            #compare pivots
            @test length(setdiff(h_pivot[:,As],C.p)) == 0
            #make device pivot matrix
            P = Matrix(1.0*I, m, m)
            for row in 1:m
                temp = copy(P[row,:])
                P[row,:] = P[h_pivot[row,As],:]
                P[h_pivot[row,As],:] = temp
            end
            @test inv(P)*dL*dU ≈ inv(C.P) * C.L * C.U
        end
    end


    @testset "getrf_batched with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
        local k
        # generate matrices
        A = [rand(elty,m,m) for i in 1:10]
        # move to device
        d_A = CuArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CuArray(A[i]))
        end
        pivot, info, d_B = CuArrays.BLAS.getrf_batched(d_A, false)
        h_info = Array(info)
        for Bs in 1:length(d_B)
            C   = lu!(copy(A[Bs]),Val(false)) # lu(A[Bs],pivot=false)
            h_B = Array(d_B[Bs])
            #reconstruct L,U
            dL = Matrix(one(elty)*I, m, m)
            dU = zeros(elty,(m,m))
            k = h_info[Bs]
            if( h_info[Bs] >= 0 )
                dU += triu(h_B,k)
                dL += tril(h_B,-k-1)
            end
            #compare
            @test C.L ≈ dL rtol=1e-2
            @test C.U ≈ dU rtol=1e-2
        end
    end

    @testset "getri_batched with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
        # generate matrices
        A = [rand(elty,m,m) for i in 1:10]
        # move to device
        d_A = CuArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CuArray(A[i]))
        end
        pivot, info = CuArrays.BLAS.getrf_batched!(d_A, true)
        h_info = Array(info)
        for Cs in 1:length(h_info)
            @test h_info[Cs] == 0
        end
        pivot, info, d_C = CuArrays.BLAS.getri_batched(d_A, pivot)
        h_info = Array(info)
        for Cs in 1:length(d_C)
            C   = inv(A[Cs])
            h_C = Array(d_C[Cs])
            @test h_info[Cs] == 0
            @test C ≈ h_C rtol=1e-2
        end
    end

    @testset "matinv_batched with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
        # generate matrices
        A = [rand(elty,m,m) for i in 1:10]
        # move to device
        d_A = CuArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CuArray(A[i]))
        end
        info, d_C = CuArrays.BLAS.matinv_batched(d_A)
        for Cs in 1:length(d_C)
            C   = inv(A[Cs])
            h_C = Array(d_C[Cs])
            @test C ≈ h_C
        end
    end

    @testset "geqrf_batched! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
        # generate matrices
        A = [rand(elty,m,n) for i in 1:10]
        # move to device
        d_A = CuArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CuArray(A[i]))
        end
        tau, d_A = CuArrays.BLAS.geqrf_batched!(d_A)
        for As in 1:length(d_A)
            C   = qr(A[As])
            h_A = Array(d_A[As])
            h_tau = Array(tau[As])
            # build up Q
            Q = Matrix(one(elty)*I, min(m,n), min(m,n))
            for i in 1:min(m,n)
                v = zeros(elty,m)
                v[i] = one(elty)
                v[i+1:m] = h_A[i+1:m,i]
                Q *= I - h_tau[i] * v * v'
            end
            @test Q ≈ Array(C.Q) rtol=1e-2
        end
    end

    @testset "geqrf_batched with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
        # generate matrices
        A = [rand(elty,m,n) for i in 1:10]
        # move to device
        d_A = CuArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CuArray(A[i]))
        end
        tau, d_B = CuArrays.BLAS.geqrf_batched!(d_A)
        for Bs in 1:length(d_B)
            C   = qr(A[Bs])
            h_B = Array(d_B[Bs])
            h_tau = Array(tau[Bs])
            # build up Q
            Q = Matrix(one(elty)*I, min(m,n), min(m,n))
            for i in 1:min(m,n)
                v = zeros(elty,m)
                v[i] = one(elty)
                v[i+1:m] = h_B[i+1:m,i]
                Q *= I - h_tau[i] * v * v'
            end
            @test Q ≈ Array(C.Q) rtol=1e-2
        end
    end

    @testset "gels_batched! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
        # generate matrices
        A = [rand(elty,n,n) for i in 1:10]
        C = [rand(elty,n,k) for i in 1:10]
        # move to device
        d_A = CuArray{elty, 2}[]
        d_C = CuArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CuArray(A[i]))
            push!(d_C,CuArray(C[i]))
        end
        d_A, d_C, info = CuArrays.BLAS.gels_batched!('N',d_A, d_C)
        for Cs in 1:length(d_C)
            X = A[Cs]\C[Cs]
            h_C = Array(d_C[Cs])
            @test X ≈ h_C rtol=1e-2
        end
    end

    @testset "gels_batched with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
        # generate matrices
        A = [rand(elty,n,n) for i in 1:10]
        C = [rand(elty,n,k) for i in 1:10]
        # move to device
        d_A = CuArray{elty, 2}[]
        d_C = CuArray{elty, 2}[]
        for i in 1:length(A)
            push!(d_A,CuArray(A[i]))
            push!(d_C,CuArray(C[i]))
        end
        d_B, d_D, info = CuArrays.BLAS.gels_batched('N',d_A, d_C)
        for Ds in 1:length(d_D)
            X = A[Ds]\C[Ds]
            h_D = Array(d_D[Ds])
            @test X ≈ h_D rtol=1e-2
        end
    end

    @testset "dgmm! with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
        # generate matrices
        A = rand(elty,m,n)
        C = rand(elty,m,n)
        x = rand(elty,m)
        # move to device
        d_A = CuArray(A)
        d_C = CuArray(C)
        d_x = CuArray(x)
        # compute
        C = diagm(0 => x) * A
        CuArrays.BLAS.dgmm!('L', d_A, d_x, d_C)
        # move to host and compare
        h_C = Array(d_C)
        @test C ≈ h_C
        # bounds checking
        @test_throws DimensionMismatch CuArrays.BLAS.dgmm!('R', d_A, d_x, d_C)
        A = rand(elty,m,m)
        d_A = CuArray(A)
        @test_throws DimensionMismatch CuArrays.BLAS.dgmm!('L', d_A, d_x, d_C)
    end

    @testset "dgmm with element type $elty" for elty in [Float32, Float64, ComplexF32, ComplexF64]
        # generate matrices
        A = rand(elty,m,n)
        x = rand(elty,m)
        # move to device
        d_A = CuArray(A)
        d_x = CuArray(x)
        # compute
        C = diagm(0 => x) * A
        d_C = CuArrays.BLAS.dgmm('L', d_A, d_x)
        # move to host and compare
        h_C = Array(d_C)
        @test C ≈ h_C
    end
end # CUSOLVER

module SavitzkyGolay

export savitzky_golay, SGolay, SGolayResults

using LinearAlgebra

struct SGolay{T1 <: Signed, T2 <: Real}
    w::T1        # Window size
    order::T1    # Polynomial order
    deriv::T1    # Derivative order
    rate::T2      # Rate
    function SGolay(w::T1, order::T1, deriv::T1, rate::T2) where {T1 <: Signed, T2 <: Real}
        isodd(w) || throw(ArgumentError("w must be an odd number."))
        w ≥ 1 || throw(ArgumentError("w must greater than or equal to 1."))
        w ≥ order + 2 || throw(ArgumentError("w too small for the polynomial order chosen (w ≥ order + 2)."))
        return new{T1, T2}(w, order, deriv, rate)
    end
end

SGolay(w, order) = SGolay(w, order, 0, 1.0)
SGolay(w, order, deriv) = SGolay(w, order, deriv, 1.0)

struct SGolayResults{T <: Float64}
    y::Vector{T}
    params::SGolay
    coeff::Vector{T}
    Vdm::Matrix{T}
end

function (p::SGolay)(y::AbstractVector)
    return _savitzky_golay(y, p)
end

function savitzky_golay(
    y::AbstractVector, window_size::T0, order::T0;
    deriv::T0=0, rate::T1=1.0,
    ) where {T0 <: Signed, T1 <: Real}
    y_, p = _check_input_sg(y, window_size, order, deriv, rate)
    return _savitzky_golay(y_, p)
end

function _savitzky_golay(y::AbstractVector, p::SGolay)
    order_range = 0 : p.order
    hw = Int64((p.w - 1) / 2) # half-window size
    V = zeros(2*hw + 1, length(order_range))
    _vandermonde!(V, hw, order_range)
    c = _coefficients(V, order_range, p)
    y_ = _padding_signal(y, hw)
    y_conv = _convolve_1d(y_, c)
    return SGolayResults(y_conv, p, c, V)
end

function _check_input_sg(y::Vector, w, order, deriv, rate)
    isodd(w) || throw(ArgumentError("w must be an odd number."))
    w ≥ 1 || throw(ArgumentError("w must greater than or equal to 1."))
    w ≥ order + 2 || throw(ArgumentError("w too small for the polynomial order chosen (w ≥ order + 2)."))
    length(y) > 1 || throw(ArgumentError("vector x must have more than one element."))
    return Float64.(y), SGolay(w, order, deriv, rate)
end

function _convolve_1d(u::AbstractVector, v::Vector)
    m = length(u)
    n = length(v)
    m > n || throw(ArgumentError("length of signal u must be greater than length of kernel v."))
    w = zeros(m + n - 1)
    @inbounds for j in 1:m, k in 1:n
        w[j+k-1] += u[j]*v[k]
    end
    return w[n:end-n+1]
end

function _vandermonde!(V::Matrix{T1}, hw::T2, order_range::UnitRange{T2}) where {T1 <: Float64, T2 <: Int64}
    @inbounds for i in -hw:hw, j in order_range
        V[i+hw+1, j+1] = i^j
    end
end

function _coefficients(V::Matrix{T1}, order_range::UnitRange{T2}, p::SGolay) where {T1 <: Float64, T2 <: Int64}
    Vqr = qr(V')
    c = Vqr.R \ (Vqr.Q' * _onehot(p.deriv + 1, length(order_range)))
    c .*= (p.rate)^(p.deriv) * factorial(p.deriv)
    return reverse(c)
end

function _onehot(i::T, m::T) where T <: Int64
    m > i || throw(ArgumentError("length of vector must be greater than the position"))
    oh = zeros(m)
    oh[i] = 1.0
    return oh
end

function _padding_signal(y::AbstractVector, hw::Int64)
    initvals = y[1] .- abs.(reverse(y[2:hw+1]) .- y[1])
    endvals = y[end] .+ abs.(reverse(y[end-hw:end-1] .- y[end]))
    return vcat(initvals, y, endvals)
end

end  # module SavitzkyGolay
